package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode/utf8"
)

type Stats struct {
	CPU        float64  `json:"cpu"`
	CPUTemp    *float64 `json:"cpu_temp"`
	NVMeTemp   *float64 `json:"nvme_temp"`
	Memory     float64  `json:"memory"`
	Disk       float64  `json:"disk"`
	Uptime     string   `json:"uptime"`
	Download   float64  `json:"download"`
	Upload     float64  `json:"upload"`
	Downloaded float64  `json:"downloaded"`
	Uploaded   float64  `json:"uploaded"`
	Power      *float64 `json:"power"`
	PowerPeak  *float64 `json:"power_peak"`
	Processes  int      `json:"processes"`
	Threads    int      `json:"threads"`
}

const (
	barWidth = 36
	width    = 1 + 10 + 1 + barWidth + 1 + 7

	bold   = "\x1b[1m"
	dim    = "\x1b[2m"
	red    = "\x1b[31m"
	green  = "\x1b[32m"
	yellow = "\x1b[33m"
	reset  = "\x1b[0m"
)

var client = &http.Client{Timeout: 2 * time.Second}

func fetch(url string) (*Stats, error) {
	res, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("stats api responded %d", res.StatusCode)
	}

	var stats Stats
	if err := json.NewDecoder(res.Body).Decode(&stats); err != nil {
		return nil, err
	}

	return &stats, nil
}

// Glances hands over a python timedelta: "4 days, 13:42:03", singular under two
// days and no day part at all under one.
var uptimePattern = regexp.MustCompile(`^(?:(\d+) days?, )?(\d+):(\d{2}):(\d{2})$`)

func parseUptime(uptime string) (time.Duration, bool) {
	match := uptimePattern.FindStringSubmatch(uptime)
	if match == nil {
		return 0, false
	}

	days, _ := strconv.Atoi(match[1])
	hours, _ := strconv.Atoi(match[2])
	minutes, _ := strconv.Atoi(match[3])
	seconds, _ := strconv.Atoi(match[4])

	return time.Duration((days*24+hours)*3600+minutes*60+seconds) * time.Second, true
}

func formatUptime(d time.Duration) string {
	total := d.Milliseconds() / 10
	days := total / 8_640_000
	clock := fmt.Sprintf("%d:%02d:%02d.%02d", total/360_000%24, total/6_000%60, total/100%60, total%100)

	if days == 0 {
		return clock
	}
	if days == 1 {
		return "1 day, " + clock
	}

	return fmt.Sprintf("%d days, %s", days, clock)
}

var units = []string{"B", "KB", "MB", "GB", "TB", "PB"}

func formatBytes(bytes float64) string {
	unit := 0
	for bytes >= 1024 && unit < len(units)-1 {
		bytes /= 1024
		unit++
	}

	if unit == 0 {
		return fmt.Sprintf("%.0f %s", bytes, units[unit])
	}

	return fmt.Sprintf("%.1f %s", bytes, units[unit])
}

func number(value float64) string {
	return strconv.FormatFloat(value, 'f', -1, 64)
}

func padLeft(text string, n int) string {
	return strings.Repeat(" ", max(n-utf8.RuneCountInString(text), 0)) + text
}

// Green until warn, yellow until crit, red beyond.
func level(value, warn, crit float64) string {
	switch {
	case value >= crit:
		return red
	case value >= warn:
		return yellow
	default:
		return green
	}
}

func gauge(label string, percent float64, text, colour string) string {
	filled := min(max(int(percent/100*barWidth+0.5), 0), barWidth)

	return fmt.Sprintf(" %s%-10s%s %s%s%s%s%s%s %s%s%s",
		dim, label, reset,
		colour, strings.Repeat("⣿", filled), reset,
		dim, strings.Repeat("⣀", barWidth-filled), reset,
		bold, padLeft(text, 7), reset,
	)
}

func stat(label, value string) string {
	return fmt.Sprintf(" %s%-10s%s %s", dim, label, reset, value)
}

type state struct {
	stats    *Stats
	bootedAt time.Time
	polledAt time.Time
	err      error
}

func header(s state) string {
	colour, indicator := yellow, "● connecting"
	switch {
	case s.err != nil || (s.stats != nil && time.Since(s.polledAt) > 3*time.Second):
		colour, indicator = red, "● offline"
	case s.stats != nil:
		colour, indicator = green, "● live"
	}

	title := " nuc.wouterds.com"
	gap := width - utf8.RuneCountInString(title) - utf8.RuneCountInString(indicator)

	return bold + title + reset + strings.Repeat(" ", max(gap, 1)) + colour + indicator + reset
}

func render(s state, url string) []string {
	lines := []string{header(s), dim + " " + strings.Repeat("─", width-1) + reset}

	if stats := s.stats; stats != nil {
		if stats.CPUTemp != nil {
			lines = append(lines, gauge("CPU temp", *stats.CPUTemp, number(*stats.CPUTemp)+"ºC", level(*stats.CPUTemp, 75, 90)))
		}
		lines = append(lines,
			gauge("CPU", stats.CPU, number(stats.CPU)+"%", level(stats.CPU, 70, 90)),
			gauge("Memory", stats.Memory, number(stats.Memory)+"%", level(stats.Memory, 70, 90)),
			gauge("Disk", stats.Disk, number(stats.Disk)+"%", level(stats.Disk, 70, 90)),
		)
		if stats.NVMeTemp != nil {
			lines = append(lines, gauge("NVMe temp", *stats.NVMeTemp, number(*stats.NVMeTemp)+"ºC", level(*stats.NVMeTemp, 60, 70)))
		}
		// Peak is whatever the meter has reported, so it is only zero before a
		// single reading has landed - which would divide the track by zero.
		if stats.Power != nil && stats.PowerPeak != nil && *stats.PowerPeak > 0 {
			power := *stats.Power
			percent := power / *stats.PowerPeak * 100
			text := fmt.Sprintf("%.1f W", power)
			if power >= 100 {
				text = fmt.Sprintf("%.0f W", power)
			}
			lines = append(lines, gauge("Power", percent, text, level(percent, 70, 90)))
		}

		uptime := stats.Uptime
		if !s.bootedAt.IsZero() {
			uptime = formatUptime(time.Since(s.bootedAt))
		}

		lines = append(lines,
			"",
			stat("Network", fmt.Sprintf("%s↓%s %.2f Mbps  %s↑%s %.2f Mbps", green, reset, stats.Download, yellow, reset, stats.Upload)),
			stat("Total", fmt.Sprintf("%s↓%s %s  %s↑%s %s", green, reset, formatBytes(stats.Downloaded), yellow, reset, formatBytes(stats.Uploaded))),
			stat("Processes", fmt.Sprintf("%d %s/ %d threads%s", stats.Processes, dim, stats.Threads, reset)),
			stat("Uptime", uptime),
		)
	}

	if s.err != nil {
		lines = append(lines, "", " "+red+s.err.Error()+reset)
	}

	return append(lines, "", dim+" "+url+" · ctrl-c to quit"+reset)
}

func main() {
	url := flag.String("url", "https://nuc.wouterds.com/api", "stats api url")
	flag.Parse()

	var (
		mu sync.Mutex
		s  state
	)

	go func() {
		for {
			stats, err := fetch(*url)

			mu.Lock()
			s.err = err
			if stats != nil {
				s.stats = stats
				s.polledAt = time.Now()
				// Only the first reading is used - the clock runs locally from
				// there, so a slow or failed poll never stalls it.
				if d, ok := parseUptime(stats.Uptime); ok && s.bootedAt.IsZero() {
					s.bootedAt = time.Now().Add(-d)
				}
			}
			mu.Unlock()

			time.Sleep(time.Second)
		}
	}()

	// Alternate screen with a hidden cursor, restored on the way out.
	fmt.Print("\x1b[?1049h\x1b[?25l")
	defer fmt.Print("\x1b[?25h\x1b[?1049l")

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)

	ticker := time.NewTicker(50 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-quit:
			return
		case <-ticker.C:
			mu.Lock()
			lines := render(s, *url)
			mu.Unlock()

			fmt.Print("\x1b[H" + strings.Join(lines, "\x1b[K\n") + "\x1b[K\x1b[J")
		}
	}
}

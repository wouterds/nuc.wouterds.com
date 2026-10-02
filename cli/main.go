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
	width    = barWidth + 9

	bold  = "\x1b[1m"
	dim   = "\x1b[2m"
	red   = "\x1b[31m"
	reset = "\x1b[0m"
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

func progress(label string, value float64, text string) []string {
	filled := min(max(int(value/100*barWidth+0.5), 0), barWidth)
	bar := strings.Repeat("█", filled) + strings.Repeat("░", barWidth-filled)

	return []string{bold + label + reset, bar + " " + dim + text + reset}
}

func stat(label, value string) string {
	gap := max(width-utf8.RuneCountInString(label)-utf8.RuneCountInString(value), 1)

	return bold + label + reset + strings.Repeat(" ", gap) + dim + value + reset
}

func render(stats *Stats, bootedAt time.Time, err error) []string {
	rule := strings.Repeat("╌", width)
	lines := []string{rule, "nuc.wouterds.com", rule, ""}

	if stats == nil {
		if err != nil {
			return append(lines, red+err.Error()+reset)
		}
		return append(lines, dim+"loading…"+reset)
	}

	if stats.CPUTemp != nil {
		lines = append(lines, progress("CPU temp", *stats.CPUTemp, number(*stats.CPUTemp)+"ºC")...)
	}
	lines = append(lines, progress("CPU usage", stats.CPU, number(stats.CPU)+"%")...)
	lines = append(lines, progress("Memory usage", stats.Memory, number(stats.Memory)+"%")...)
	lines = append(lines, progress("Disk usage", stats.Disk, number(stats.Disk)+"%")...)
	if stats.NVMeTemp != nil {
		lines = append(lines, progress("NVMe temp", *stats.NVMeTemp, number(*stats.NVMeTemp)+"ºC")...)
	}
	// Peak is whatever the meter has reported, so it is only zero before a
	// single reading has landed - which would divide the track by zero.
	if stats.Power != nil && stats.PowerPeak != nil && *stats.PowerPeak > 0 {
		power := *stats.Power
		text := fmt.Sprintf("%.1f W", power)
		if power >= 100 {
			text = fmt.Sprintf("%.0f W", power)
		}
		lines = append(lines, progress("Power draw", power / *stats.PowerPeak * 100, text)...)
	}

	uptime := stats.Uptime
	if !bootedAt.IsZero() {
		uptime = formatUptime(time.Since(bootedAt))
	}

	lines = append(lines,
		"",
		strings.Repeat("╌", width),
		stat("Network", fmt.Sprintf("↓ %.2f Mbps ↑ %.2f Mbps", stats.Download, stats.Upload)),
		stat("Transferred", fmt.Sprintf("↓ %s ↑ %s", formatBytes(stats.Downloaded), formatBytes(stats.Uploaded))),
		stat("Processes", fmt.Sprintf("%d / %d threads", stats.Processes, stats.Threads)),
		stat("Uptime", uptime),
	)

	if err != nil {
		lines = append(lines, "", red+err.Error()+reset)
	}

	return lines
}

func main() {
	url := flag.String("url", "https://nuc.wouterds.com/api", "stats api url")
	flag.Parse()

	var (
		mu       sync.Mutex
		stats    *Stats
		bootedAt time.Time
		lastErr  error
	)

	go func() {
		for {
			next, err := fetch(*url)

			mu.Lock()
			lastErr = err
			if next != nil {
				stats = next
				// Only the first reading is used - the clock runs locally from
				// there, so a slow or failed poll never stalls it.
				if d, ok := parseUptime(next.Uptime); ok && bootedAt.IsZero() {
					bootedAt = time.Now().Add(-d)
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
			lines := render(stats, bootedAt, lastErr)
			mu.Unlock()

			fmt.Print("\x1b[H" + strings.Join(lines, "\x1b[K\n") + "\x1b[K\x1b[J")
		}
	}
}

import { useEffect } from "react";
import { useRevalidator } from "react-router";

import Progress from "~/components/progress";
import Stat from "~/components/stat";
import type { Route } from "./+types/home";

export const meta: Route.MetaFunction = () => {
  return [{ title: "nuc.wouterds.com" }];
};

const units = ["B", "KB", "MB", "GB", "TB", "PB"];

const formatBytes = (bytes: number) => {
  let value = bytes;
  let unit = 0;

  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }

  return `${value.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`;
};

export const loader = async () => {
  // The page polls faster than once a second, so a hung upstream would stack
  // requests up behind each other rather than ever failing.
  const response = await fetch(process.env.API_URL!, { signal: AbortSignal.timeout(2000) });

  // Without this a non-200 falls through to res.json(), which chokes on the
  // error body and surfaces a parser error instead of what actually went wrong.
  if (!response.ok) {
    throw new Error(`Stats api responded ${response.status}`);
  }

  return (await response.json()) as {
    cpu: number;
    cpu_temp: number | null;
    nvme_temp: number | null;
    memory: number;
    disk: number;
    uptime: string;
    download: number;
    upload: number;
    downloaded: number;
    uploaded: number;
    power: number | null;
    power_peak: number | null;
    processes: number;
    threads: number;
  };
};

export default function Index({ loaderData }: Route.ComponentProps) {
  const { revalidate, state } = useRevalidator();

  useEffect(() => {
    if (state !== "loading") {
      const timeout = setTimeout(() => {
        revalidate();
      }, 900);

      return () => clearTimeout(timeout);
    }
  }, [state, revalidate]);

  const { cpu_temp, nvme_temp, download, upload, downloaded, uploaded } = loaderData;
  const { power, power_peak, processes, threads, uptime } = loaderData;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        {cpu_temp !== null && <Progress label="CPU temp" progress={cpu_temp} unit="ºC" />}
        <Progress label="CPU usage" progress={loaderData.cpu} />
        <Progress label="Memory usage" progress={loaderData.memory} />
        <Progress label="Disk usage" progress={loaderData.disk} />
        {nvme_temp !== null && <Progress label="NVMe temp" progress={nvme_temp} unit="ºC" />}
        {/* Peak is whatever the meter has reported, so it is only zero before
            a single reading has landed - which would divide the track by zero. */}
        {power !== null && power_peak !== null && power_peak > 0 && (
          <Progress
            label="Power draw"
            progress={(power / power_peak) * 100}
            value={`${power >= 100 ? power.toFixed(0) : power.toFixed(1)} W`}
          />
        )}
      </div>

      <div className="flex flex-col gap-1 border-t border-dashed border-zinc-300 pt-3 dark:border-zinc-700">
        <Stat label="Network" value={`↓ ${download.toFixed(2)} ↑ ${upload.toFixed(2)} Mbps`} />
        <Stat
          label="Transferred"
          value={`↓ ${formatBytes(downloaded)} ↑ ${formatBytes(uploaded)}`}
        />
        <Stat label="Processes" value={`${processes} / ${threads} threads`} />
        <Stat label="Uptime" value={uptime} />
      </div>
    </div>
  );
}

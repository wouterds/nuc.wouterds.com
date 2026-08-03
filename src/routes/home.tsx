import { useEffect } from "react";
import { useRevalidator } from "react-router";

import Progress from "~/components/progress";
import Stat from "~/components/stat";
import type { Route } from "./+types/home";

export const meta: Route.MetaFunction = () => {
  return [{ title: "nuc.wouterds.com" }];
};

export const loader = async () => {
  const data = await fetch(process.env.API_URL!).then(
    (res) =>
      res.json() as Promise<{
        cpu: number;
        cpu_temp: number | null;
        nvme_temp: number | null;
        memory: number;
        disk: number;
        uptime: string;
        download: number;
        upload: number;
        processes: number;
        threads: number;
      }>,
  );

  return data;
};

export default function Index({ loaderData }: Route.ComponentProps) {
  const { revalidate, state } = useRevalidator();

  useEffect(() => {
    if (state !== "loading") {
      const timeout = setTimeout(() => {
        revalidate();
      }, 1000);

      return () => clearTimeout(timeout);
    }
  }, [state, revalidate]);

  const { cpu_temp, nvme_temp, download, upload, processes, threads, uptime } = loaderData;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        {cpu_temp !== null && <Progress label="CPU temp" progress={cpu_temp} unit="ºC" />}
        <Progress label="CPU usage" progress={loaderData.cpu} />
        <Progress label="Memory usage" progress={loaderData.memory} />
        <Progress label="Disk usage" progress={loaderData.disk} />
        {nvme_temp !== null && <Progress label="NVMe temp" progress={nvme_temp} unit="ºC" />}
      </div>

      <div className="flex flex-col gap-1 border-t border-dashed border-zinc-300 pt-3 dark:border-zinc-700">
        <Stat label="Network" value={`↓ ${download.toFixed(2)} ↑ ${upload.toFixed(2)} Mbps`} />
        <Stat label="Processes" value={`${processes} / ${threads} threads`} />
        <Stat label="Uptime" value={uptime} />
      </div>
    </div>
  );
}

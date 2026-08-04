// biome-ignore lint/style/useNodejsImportProtocol: njs is not node, there is no node: prefix
import fs from "fs";

const PLUGINS = ["cpu", "mem", "sensors", "fs", "uptime", "processcount"];
const DISKS = ["/mnt/disk1", "/mnt/disk2"];
const INTERFACE = "enp87s0";

// /proc/net is scoped to the reading process's network namespace, and nginx has
// its own, so its /proc/net/dev only ever describes a veth carrying the poll
// traffic itself. Pid 1 in the mounted host /proc sits in the host namespace.
const NET_DEV = "/host/proc/1/net/dev";

const sensorValue = (sensors, label) => {
  const sensor = sensors.find((entry) => entry.label === label);

  return sensor ? sensor.value : null;
};

const toMbps = (bytesPerSecond) => Math.round((bytesPerSecond * 8) / 1000) / 1000;

const readInterface = () => {
  const line = fs
    .readFileSync(NET_DEV, "utf8")
    .split("\n")
    .find((entry) => entry.trim().indexOf(`${INTERFACE}:`) === 0);

  if (!line) {
    return null;
  }

  const columns = line.trim().split(/\s+/);

  return { received: Number(columns[1]), sent: Number(columns[9]) };
};

// Counters are cumulative, so throughput is the delta against the last poll.
// A reboot or interface reset rewinds them, hence the floor at zero.
const throughput = (counters) => {
  const now = Date.now();
  const previous = ngx.shared.network.get("sample");
  ngx.shared.network.set("sample", `${now}:${counters.received}:${counters.sent}`);

  if (!previous) {
    return { download: 0, upload: 0 };
  }

  const parts = previous.split(":");
  const seconds = (now - Number(parts[0])) / 1000;

  if (seconds <= 0) {
    return { download: 0, upload: 0 };
  }

  return {
    download: toMbps(Math.max(counters.received - Number(parts[1]), 0) / seconds),
    upload: toMbps(Math.max(counters.sent - Number(parts[2]), 0) / seconds),
  };
};

export default async (r) => {
  try {
    const responses = await Promise.all(
      PLUGINS.map((plugin) => r.subrequest(`/glances/api/4/${plugin}`, { method: "GET" })),
    );

    const failed = responses.find((res) => res.status !== 200);
    if (failed) {
      r.return(failed.status, failed.responseBody);
      return;
    }

    // njs has no destructuring, so key the parsed payloads by plugin name.
    const data = {};
    PLUGINS.forEach((plugin, index) => {
      data[plugin] = JSON.parse(responses[index].responseText);
    });

    const disk = data.fs.reduce(
      (acc, entry) => {
        if (DISKS.includes(entry.mnt_point)) {
          acc.size += entry.size;
          acc.used += entry.used;
        }
        return acc;
      },
      { size: 0, used: 0 },
    );

    const counters = readInterface();
    const rates = counters ? throughput(counters) : { download: 0, upload: 0 };

    r.headersOut["Content-Type"] = "application/json";
    r.return(
      200,
      JSON.stringify({
        cpu: data.cpu.total,
        cpu_temp: sensorValue(data.sensors, "Package id 0"),
        nvme_temp: sensorValue(data.sensors, "Composite"),
        memory: data.mem.percent,
        disk: Math.round((disk.used / disk.size) * 10000) / 100,
        uptime: data.uptime,
        download: rates.download,
        upload: rates.upload,
        downloaded: counters ? counters.received : 0,
        uploaded: counters ? counters.sent : 0,
        processes: data.processcount.total,
        threads: data.processcount.thread,
      }),
    );
  } catch (e) {
    r.error(`Error processing response: ${e}`);
    r.return(500, `Error processing response: ${e}`);
  }
};

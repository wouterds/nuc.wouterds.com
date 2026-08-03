const PLUGINS = ["cpu", "mem", "sensors", "fs", "uptime", "network", "processcount"];
const DISKS = ["/mnt/disk1", "/mnt/disk2"];
const INTERFACE = "eth0";

const sensorValue = (sensors, label) => {
  const sensor = sensors.find((entry) => entry.label === label);

  return sensor ? sensor.value : null;
};

const toMbps = (bytesPerSecond) => Math.round((bytesPerSecond * 8) / 1000) / 1000;

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

    const nic = data.network.find((entry) => entry.interface_name === INTERFACE);

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
        download: nic ? toMbps(nic.bytes_recv_rate_per_sec) : 0,
        upload: nic ? toMbps(nic.bytes_sent_rate_per_sec) : 0,
        processes: data.processcount.total,
        threads: data.processcount.thread,
      }),
    );
  } catch (e) {
    r.error(`Error processing response: ${e}`);
    r.return(500, `Error processing response: ${e}`);
  }
};

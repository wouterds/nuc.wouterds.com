const PLUGINS = ["cpu", "mem", "sensors", "fs"];
const DISKS = ["/mnt/disk1", "/mnt/disk2"];

const sensorValue = (sensors, label) => {
  const sensor = sensors.find((entry) => entry.label === label);

  return sensor ? sensor.value : null;
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

    r.headersOut["Content-Type"] = "application/json";
    r.return(
      200,
      JSON.stringify({
        cpu: data.cpu.total,
        cpu_temp: sensorValue(data.sensors, "Package id 0"),
        memory: data.mem.percent,
        disk: Math.round((disk.used / disk.size) * 10000) / 100,
      }),
    );
  } catch (e) {
    r.error(`Error processing response: ${e}`);
    r.return(500, `Error processing response: ${e}`);
  }
};

export default (r) => {
  r.subrequest('/glances/api/4/all', { method: 'GET' }, (res) => {
    if (res.status !== 200) {
      r.return(res.status, res.responseBody);
      return;
    }

    try {
      const data = JSON.parse(res.responseText);

      const cpu = {
        usage: data.cpu.total,
        temp: data.sensors.find(sensor => sensor.label === 'Package id 0').value,
      };

      const memory = data.mem;

      const disk = data.fs.reduce((acc, entry) => {
        if (['/mnt/disk2', '/mnt/disk1'].includes(entry.mnt_point)) {
          acc.size += entry.size;
          acc.used += entry.used;
        }
        return acc;
      }, { size: 0, used: 0, percent: 0 });

      disk.percent = Math.round((disk.used / disk.size) * 10000) / 100;

      r.headersOut['Content-Type'] = 'application/json';
      r.return(200, JSON.stringify({
        cpu: cpu.usage,
        cpu_temp: cpu.temp,
        memory: memory.percent,
        disk: disk.percent,
      }));
    } catch (e) {
      r.error(`Error processing response: ${e}`);
      r.return(500, `Error processing response: ${e}`);
    }
  });
};

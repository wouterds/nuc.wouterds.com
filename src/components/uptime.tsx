import { useEffect, useState } from "react";

import Stat from "~/components/stat";

type Props = {
  uptime: string;
};

// Glances hands over a python timedelta: "4 days, 13:42:03", singular under two
// days and no day part at all under one.
const parse = (uptime: string) => {
  const match = uptime.match(/^(?:(\d+) days?, )?(\d+):(\d{2}):(\d{2})$/);
  if (!match) {
    return null;
  }

  const [, days, hours, minutes, seconds] = match;

  return (
    ((Number(days ?? 0) * 24 + Number(hours)) * 3600 + Number(minutes) * 60 + Number(seconds)) *
    1000
  );
};

const pad = (value: number) => value.toString().padStart(2, "0");

// Counting in hundredths keeps the seconds off floating point, where a rounded
// 59.999 would surface as ":60.00".
const format = (ms: number) => {
  const total = Math.floor(ms / 10);
  const days = Math.floor(total / 8_640_000);
  const clock = [
    Math.floor(total / 360_000) % 24,
    pad(Math.floor(total / 6_000) % 60),
    `${pad(Math.floor(total / 100) % 60)}.${pad(total % 100)}`,
  ].join(":");

  if (days === 0) {
    return clock;
  }

  return `${days} day${days === 1 ? "" : "s"}, ${clock}`;
};

const Uptime = ({ uptime }: Props) => {
  // Only the first reading is used - the clock runs off the browser from there,
  // so a slow or failed poll never stalls it.
  const [initial] = useState(() => parse(uptime));
  const [elapsed, setElapsed] = useState(initial);

  useEffect(() => {
    if (initial === null) {
      return;
    }

    const bootedAt = Date.now() - initial;
    let frame = requestAnimationFrame(function tick() {
      setElapsed(Date.now() - bootedAt);
      frame = requestAnimationFrame(tick);
    });

    return () => cancelAnimationFrame(frame);
  }, [initial]);

  // A format we cannot read is still worth showing as-is.
  if (elapsed === null) {
    return <Stat label="Uptime" value={uptime} />;
  }

  return <Stat label="Uptime" value={format(elapsed)} />;
};

export default Uptime;

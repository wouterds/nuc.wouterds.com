type Props = {
  progress: number;
  label?: string;
  unit?: string;
  // For gauges whose reading is not what fills the track, like power drawn
  // against the highest draw seen so far.
  value?: string;
};

const filledChar = "█";
const emptyChar = "░";
const width = 36;

const Progress = ({ progress, label, unit = "%", value }: Props) => {
  // Temperatures are fed in as-is and this box idles in the 90s, so a reading
  // over 100 would otherwise ask for a negative amount of empty track and throw.
  const filledWidth = Math.min(Math.max(Math.round((progress / 100) * width), 0), width);
  const emptyWidth = width - filledWidth;
  const text = value ?? `${progress}${unit}`;

  return (
    <div className="text-xs">
      {label && <div className="text-zinc-900 dark:text-zinc-100">{label}</div>}
      <div
        className="flex items-center"
        role="progressbar"
        aria-label={label}
        aria-valuenow={progress}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuetext={text}
      >
        <span className="text-zinc-900 dark:text-zinc-100 tracking-wider" aria-hidden="true">
          {filledChar.repeat(filledWidth) + emptyChar.repeat(emptyWidth)}
        </span>
        {/* Pinned so every gauge row is the same width whatever the reading
            says, otherwise the container would resize on each poll as values
            move between "9.5%" and "42.61%". */}
        <span
          className="ml-2 min-w-[6ch] whitespace-nowrap text-zinc-600 dark:text-zinc-400"
          aria-hidden="true"
        >
          {text}
        </span>
      </div>
    </div>
  );
};

export default Progress;

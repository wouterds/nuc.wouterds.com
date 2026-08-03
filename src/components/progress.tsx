type Props = {
  progress: number;
  width?: number;
  label?: string;
  unit?: string;
};

const filledChar = "█";
const emptyChar = "░";
const width = 36;

const Progress = ({ progress, label, unit = "%" }: Props) => {
  // Temperatures are fed in as-is and this box idles in the 90s, so a reading
  // over 100 would otherwise ask for a negative amount of empty track and throw.
  const filledWidth = Math.min(Math.max(Math.round((progress / 100) * width), 0), width);
  const emptyWidth = width - filledWidth;

  return (
    <div className="text-xs">
      {label && <div className="text-zinc-900 dark:text-zinc-100">{label}</div>}
      <div className="flex items-center">
        <span className="text-zinc-900 dark:text-zinc-100 tracking-wider">
          {filledChar.repeat(filledWidth) + emptyChar.repeat(emptyWidth)}
        </span>
        <span className="ml-2 text-zinc-600 dark:text-zinc-400">{`${progress}${unit}`}</span>
      </div>
    </div>
  );
};

export default Progress;

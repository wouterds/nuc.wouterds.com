type Props = {
  label: string;
  value: string;
};

const Stat = ({ label, value }: Props) => (
  <div className="flex items-baseline justify-between gap-2 text-xs">
    <span className="text-zinc-900 dark:text-zinc-100">{label}</span>
    <span className="text-zinc-600 dark:text-zinc-400">{value}</span>
  </div>
);

export default Stat;

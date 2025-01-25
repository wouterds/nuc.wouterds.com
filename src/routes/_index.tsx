import type { MetaFunction } from '@remix-run/node';
import { useLoaderData, useRevalidator } from '@remix-run/react';
import { useEffect } from 'react';

import Progress from '~/components/progress';

export const meta: MetaFunction = () => {
  return [{ title: 'nuc.wouterds.com' }];
};

export const loader = async () => {
  const data = await fetch(process.env.API_URL!).then(
    (res) =>
      res.json() as Promise<{
        cpu: number;
        cpu_temp: number;
        memory: number;
        disk: number;
      }>,
  );

  return data;
};

export default function Index() {
  const data = useLoaderData<typeof loader>();
  const { revalidate, state } = useRevalidator();

  useEffect(() => {
    if (state !== 'loading') {
      const timeout = setTimeout(() => {
        revalidate();
      }, 1000);

      return () => clearTimeout(timeout);
    }
  }, [state, revalidate]);

  return (
    <div className="font-mono text-xs">
      <div className="flex flex-col gap-2">
        <Progress label="CPU temp" progress={data.cpu_temp} unit="ºC" />
        <Progress label="CPU usage" progress={data.cpu} />
        <Progress label="Memory usage" progress={data.memory} />
        <Progress label="Disk usage" progress={data.disk} />
      </div>
    </div>
  );
}

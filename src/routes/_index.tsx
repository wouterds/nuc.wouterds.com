import type { MetaFunction } from '@remix-run/node';
import { useLoaderData, useRevalidator } from '@remix-run/react';
import { useEffect } from 'react';

export const meta: MetaFunction = () => {
  return [{ title: 'nuc.wouterds.be' }];
};

export const loader = async () => {
  const data = await fetch(process.env.API_URL!);

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
    <div className="font-mono text-xs p-6">
      <pre className="whitespace-pre-wrap">
        <code>{JSON.stringify(data, null, 2)}</code>
      </pre>
    </div>
  );
}

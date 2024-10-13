import './tailwind.css';

import type { LinksFunction, LoaderFunctionArgs } from '@remix-run/node';
import { Links, Meta, Outlet, Scripts, useLoaderData } from '@remix-run/react';

import Footer from './components/footer';
import Header from './components/header';

export const links: LinksFunction = () => [
  { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
  {
    rel: 'preconnect',
    href: 'https://fonts.gstatic.com',
    crossOrigin: 'anonymous',
  },
  {
    rel: 'stylesheet',
    href: 'https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&display=swap',
  },
];

export const loader = async ({ request }: LoaderFunctionArgs) => {
  return {
    ray: request.headers.get('cf-ray'),
  };
};

const App = () => {
  const { ray } = useLoaderData<typeof loader>();

  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <Meta />
        <Links />
      </head>
      <body>
        <div className="mx-auto max-w-sm">
          <Header />
          <main className="py-6">
            <Outlet />
          </main>
          <Footer ray={ray} />
        </div>
        {/* <ScrollRestoration /> */}
        <Scripts />
      </body>
    </html>
  );
};

export default App;

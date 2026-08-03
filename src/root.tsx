import "./tailwind.css";

import { Links, Meta, Outlet, Scripts, ScrollRestoration } from "react-router";
import type { Route } from "./+types/root";
import Footer from "./components/footer";
import Header from "./components/header";

export const loader = async ({ request }: Route.LoaderArgs) => {
  return {
    ray: request.headers.get("cf-ray"),
  };
};

const App = ({ loaderData }: Route.ComponentProps) => {
  const { ray } = loaderData;

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
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
};

export default App;

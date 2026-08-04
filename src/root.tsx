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

// Cloudflare stamps a new ray on every request, so letting this loader run
// again on the once-a-second poll would hand the footer a different id each
// time and restart the typewriter mid-word. The ray identifies the page load,
// not the poll, so it is read once and kept.
export const shouldRevalidate = () => false;

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

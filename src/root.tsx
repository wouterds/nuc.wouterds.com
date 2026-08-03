import "./tailwind.css";

import { Links, Meta, Outlet, Scripts, ScrollRestoration } from "react-router";
import type { Route } from "./+types/root";
import Footer from "./components/footer";
import Header from "./components/header";

export const links: Route.LinksFunction = () => [
  { rel: "preconnect", href: "https://fonts.googleapis.com" },
  {
    rel: "preconnect",
    href: "https://fonts.gstatic.com",
    crossOrigin: "anonymous",
  },
  {
    rel: "stylesheet",
    href: "https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&display=swap",
  },
];

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

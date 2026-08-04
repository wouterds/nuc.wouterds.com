import "./tailwind.css";

import {
  isRouteErrorResponse,
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
} from "react-router";
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

// Wraps both the app and the error boundary, so a thrown error still renders
// inside a real document with the stylesheet attached.
export const Layout = ({ children }: { children: React.ReactNode }) => (
  <html lang="en">
    <head>
      <meta charSet="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <Meta />
      <Links />
    </head>
    <body>
      <div className="mx-auto max-w-readout">{children}</div>
      <ScrollRestoration />
      <Scripts />
    </body>
  </html>
);

const App = ({ loaderData }: Route.ComponentProps) => (
  <>
    <Header />
    <main className="py-6">
      <Outlet />
    </main>
    <Footer ray={loaderData.ray} />
  </>
);

export const ErrorBoundary = ({ error }: Route.ErrorBoundaryProps) => {
  const isResponse = isRouteErrorResponse(error);
  const status = isResponse ? error.status : 500;
  const detail = isResponse && status === 404 ? "no such page" : "stats unavailable";

  return (
    <>
      <Header />
      <main className="py-6">
        <div className="flex flex-col gap-2">
          <div className="text-zinc-900 dark:text-zinc-100">{`${status} ${detail}`}</div>
          <div className="tracking-wider text-zinc-400 dark:text-zinc-500">{"░".repeat(36)}</div>
          {import.meta.env.DEV && error instanceof Error && error.stack && (
            <pre className="mt-2 overflow-x-auto text-zinc-600 dark:text-zinc-400">
              {error.stack}
            </pre>
          )}
        </div>
      </main>
      <Footer />
    </>
  );
};

export default App;

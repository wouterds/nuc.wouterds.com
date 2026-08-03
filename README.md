# nuc.wouterds.com

Live stats for my home NUC — CPU temperature, CPU, memory and disk usage,
rendered as ASCII progress bars. [nuc.wouterds.com](https://nuc.wouterds.com)

Stats come from [glances](https://github.com/nicolargo/glances), reshaped by an
njs script in nginx (`.docker/stats.js`) and served at `/api`. The page polls it
once a second.

## Stack

React Router 8, React 19, Tailwind 4, Vite 8, TypeScript 7, Node 24. Biome for
lint and formatting, knip for dead code.

## Development

```sh
npm install
npm run dev
```

Set `API_URL` in `.env` — see `.env.example`.

| Command | |
| --- | --- |
| `npm run dev` | dev server |
| `npm run build` | production build |
| `npm run lint:fix` | lint and format |
| `npm run typecheck` | typegen and typecheck |

## Deployment

Pushing to `main` builds the image, pushes it to `ghcr.io` tagged `latest` and
the short commit SHA, then deploys over an SSH-through-Cloudflare-tunnel to the
NUC, where nginx fronts the app and proxies glances.

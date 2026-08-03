# AGENTS.md

Single-page dashboard showing live stats for a home NUC, as ASCII progress bars.
See [README.md](README.md) for the stack and how it deploys.

## Commands

- **Lint & typecheck**: `npm run lint:fix && npm run typecheck`
- **Dead code**: `npx knip`

## Rules

- **NEVER** bypass pre-commit hooks (`--no-verify`, `LEFTHOOK=0`)
- **NEVER** call biome directly — use `npm run lint` or `npm run lint:fix`
- **NEVER** commit without being explicitly asked
- Atomic commits, conventional messages, max 100 chars per line
- Prefer the smallest change that does the job
- Find root causes — no temporary or hacky fixes
- Focus on what is asked — no out-of-scope refactors

## Layout

`src/routes.ts` declares routes explicitly; there is no file-based convention.
Route modules take their loader data from the generated `./+types/*` namespace,
not `useLoaderData`. Everything deployment-related lives in `.docker/`.

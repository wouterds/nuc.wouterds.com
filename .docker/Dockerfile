FROM node:24-alpine AS base
WORKDIR /code

FROM base AS deps

COPY package.json package-lock.json ./
RUN npm ci

FROM deps AS prod-deps

RUN npm prune --omit=dev

FROM deps AS build

COPY . .
RUN npm run build

FROM base AS runtime
WORKDIR /code

RUN apk add --no-cache libc6-compat dumb-init

COPY --chown=node:node --from=build /code/build ./build
COPY --chown=node:node --from=prod-deps /code/package.json ./package.json
COPY --chown=node:node --from=prod-deps /code/package-lock.json ./package-lock.json
COPY --chown=node:node --from=prod-deps /code/node_modules ./node_modules

ARG COMMIT_SHA
ENV COMMIT_SHA=$COMMIT_SHA
ENV PORT=3000
ENV HOST=0.0.0.0
ENV NODE_ENV=production

USER node
EXPOSE $PORT

ENTRYPOINT ["dumb-init", "--"]
CMD ["npm", "run", "start"]

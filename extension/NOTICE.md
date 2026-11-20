# About this folder

This is a copy of the browser extension from the **vitap-mate** project
(`../vitap-mate/extension`), brought into this repository as a starting point.
It is MIT licensed (see `LICENSE`); keep that file and the copyright notice with
any copy of this code.

## It is not connected to V-Sync yet

Nothing in the V-Sync app talks to this extension today, and no Settings entry
exists for it. That is deliberate, because of how the extension works:

- It does **not** talk to the phone directly. It talks to a **server**
  (`POST /v1/pair`, `/v1/...`, see vitap-mate's `rust/vtop-edge/API.md`), which
  relays to the phone, or answers from its own cache, or signs in to VTOP itself.
- The address of that server is baked in at build time from `VITE_BRIDGE_URL`
  and **defaults to the senior's server, `https://vmate.aster0.dev`**
  (`vite.config.ts`, `src/bridge.ts`). `.env` was left out of this copy on
  purpose. Building this folder as-is would point it at a server that knows
  nothing about V-Sync.
- That server keeps sealed VTOP sessions, and for server-side sign-in a sealed
  password. Sending V-Sync users' sessions or credentials there, or running
  our own equivalent, is a product and privacy decision, not a code change.

Until that decision is made, treat this folder as reference material.

## Develop

See `README.md` (written for the original project): `bun install`,
`bun run test`, `bun run check`, `bun run build`.

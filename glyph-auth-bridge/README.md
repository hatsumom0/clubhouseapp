# glyph-auth-bridge

Web bridge that gives the BAYC Clubhouse iOS app a real [Glyph](https://useglyph.io) login.
Glyph ships no native SDK, so the app opens this page in `ASWebAuthenticationSession`;
the page runs `@use-glyph/sdk-react`, authenticates the member (X / email / wallet),
signs a nonce'd membership-proof message, and deep-links back to
`baycclubhouse://glyph-auth` with the address, signature, and every wallet on the
Glyph account (embedded + smart + linked vaults).

The Worker (`worker/index.ts`) also exposes `POST /verify` — server-side signature
verification (EOA ecrecover + ERC-1271/6492 on ApeChain and mainnet). The app fails
closed on it; a future door/QR backend should call the same endpoint.

## Develop

```bash
npm install
npm run dev        # http://localhost:5173 (simulator reaches the Mac's localhost)
```

## Deploy

Deployed as a Cloudflare Worker with static assets (see `wrangler.jsonc`):

```bash
npm run build
npx wrangler deploy
```

Git pushes to `main` also auto-deploy via Cloudflare Workers Builds
(path `/glyph-auth-bridge`, build `npm run build`, deploy `npx wrangler deploy`).

Live: https://clubhouseapp.vfsp2wqysh.workers.dev

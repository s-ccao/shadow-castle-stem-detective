# Web publishing

Two Vercel projects, one repository. The portfolio site stays small and
redeploys on every push; the game payload is tens of megabytes and is deployed
and rolled back on its own schedule.

| Hostname | Vercel project root | Deploys from | Purpose |
| --- | --- | --- | --- |
| `shadowcastledetective.com` | `web/landing` | Git push (automatic) | Game and portfolio site |
| `www.shadowcastledetective.com` | — | Redirect to apex | Canonical-domain redirect |
| `play.shadowcastledetective.com` | `web/game` | Built export (see below) | Browser-playable game |

## Why the game site is not a plain Git deploy

Vercel's build image has no Godot and no export templates, and the export
artifacts are deliberately not committed — the filenames are fixed, so every
build would add another ~40MB `index.wasm` + `index.pck` pair to a repository
that is already 680MB. Connecting `web/game` to Git with no build step would
therefore publish an empty folder.

The build happens somewhere that *can* run Godot: your machine, or the
`Web export` GitHub Actions workflow. Only the result is uploaded.

## Building the export

Prerequisite, once per machine: **Editor > Manage Export Templates** and install
the templates for **exactly** the running editor version (4.7.stable). A
mismatch is the "No export template found" error.

The `Web` preset is committed in `export_presets.cfg`, so there is nothing to
configure — open **Project > Export** to confirm Godot agrees with it, then
either press *Export Project* or use the command line:

```bash
# From the project root. The preset name is case- and space-sensitive.
godot --headless --export-release "Web" web/game/index.html
```

The preset is deliberately **single-threaded** (`variant/thread_support=false`)
and the project already renders with **GL Compatibility**. Single-threaded
builds do not need `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy`
headers, which is what keeps the game working on iOS Safari and on any host
that will not set custom headers. If threads are ever enabled, both headers
become mandatory and `web/game/vercel.json` has to set them.

Godot writes fixed filenames (`index.html`, `index.js`, `index.wasm`,
`index.pck`, ...), so `web/game/vercel.json` serves everything with
`max-age=0, must-revalidate`. Browsers still get a cheap 304 from the ETag when
nothing changed, and a new build is picked up immediately instead of being
served from a stale cache for a year.

## Deploying the game

```bash
# One-off, from the project root, after building:
npx vercel deploy web/game --prod
```

Or run the **Web export** workflow from the Actions tab with *Deploy to Vercel*
ticked, which needs three repository secrets: `VERCEL_TOKEN`, `VERCEL_ORG_ID`
and `VERCEL_GAME_PROJECT_ID`. Without them the workflow still builds, verifies
and uploads the result as a downloadable artifact.

Tagging a release (`git tag v1.0.0 && git push --tags`) builds and deploys.

## Steps that need your account, not this repository

These cannot be scripted from here — they need a logged-in Vercel session and
registrar access:

1. **Vercel > Add New > Project**, import `s-ccao/shadow-castle-stem-detective`.
   Framework preset **Other**, root directory `web/landing`, no build command.
   This is the site project.
2. **Vercel > Add New > Project** again for the game. Root directory
   `web/game`, framework preset **Other**, no build command. It will deploy
   empty until the first export is uploaded — that is expected.
3. **Settings > Domains** on the site project: add `shadowcastledetective.com`
   and `www.shadowcastledetective.com`, and set `www` to redirect to the apex.
4. **Settings > Domains** on the game project: add
   `play.shadowcastledetective.com`.
5. **Namecheap > Advanced DNS**: add the records Vercel shows you. At the time
   of writing that is an `A` record on `@` pointing at `76.76.21.21` and a
   `CNAME` on `play` (and `www`) pointing at the value on the Domains page —
   **use the values Vercel prints, not these**, because they change.
   Leave every existing `MX` and `TXT` record alone or email stops working.
6. Wait for Vercel to report the domains as valid. HTTPS is issued
   automatically once DNS resolves.

## Registrar

Namecheap remains the registrar and DNS owner. The landing images under
`web/landing/assets/` are compressed copies of project-owned art; the source
game assets stay in their own folders. `web/.gdignore` keeps the whole web tree
out of the Godot import pipeline, so none of it is packed into the game.

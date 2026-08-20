# Web publishing

Two Vercel projects, one repository. The portfolio site stays small and
redeploys on every push; the game payload is tens of megabytes and is deployed
and rolled back on its own schedule.

| Hostname | Vercel project | Deploys from | Purpose |
| --- | --- | --- | --- |
| `shadowcastledetective.com` | `shadow-castle-detective-site` (`web/landing`) | Git push (automatic) | Game and portfolio site |
| `www.shadowcastledetective.com` | same | Redirect to apex | Canonical-domain redirect |
| `play.shadowcastledetective.com` | `shadow-castle-detective-play` (`web/game`) | Built export (see below) | Browser-playable game |

All three are live over HTTPS. `web/game/.vercel/project.json` links the game
directory to its project, so `npx vercel --prod` from that directory redeploys
without asking anything.

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
# From web/game, which is already linked to the project:
cd web/game && npx vercel --prod
```

The CLI falls back to `.gitignore` when a directory has no `.vercelignore`, and
`web/game/.gitignore` is `*`. Without `web/game/.vercelignore` the deploy
succeeds while uploading nothing but `vercel.json` — a working URL serving a
404. That file existing is the only thing preventing it, so do not delete it.

Or run the **Web export** workflow from the Actions tab with *Deploy to Vercel*
ticked, which needs three repository secrets: `VERCEL_TOKEN`, `VERCEL_ORG_ID`
and `VERCEL_GAME_PROJECT_ID`. Without them the workflow still builds, verifies
and uploads the result as a downloadable artifact.

Tagging a release (`git tag v1.0.0 && git push --tags`) builds and deploys.

### Checking that a deploy is real

Every way this can fail — a truncated upload, the `.vercelignore` trap, a host
that rewrites unknown extensions — produces a page that loads and a game that
does not start. Compare sizes against the local build and check the two MIME
types that matter:

```bash
for f in index.html index.js index.wasm index.pck; do
  printf '%-12s ' "$f"
  curl -sS -o /dev/null -w '%{http_code} %{size_download}B %{content_type}\n' \
    "https://play.shadowcastledetective.com/$f"
done
```

`index.wasm` must come back as `application/wasm`; anything else and the
browser cannot stream-compile it. Sizes must match `ls -l web/game/` exactly.
For a stronger check the payloads are self-identifying — `index.pck` starts
with `GDPC` and `index.wasm` with `\0asm`:

```bash
curl -sS -r 0-3 https://play.shadowcastledetective.com/index.pck | xxd
```

## Domains and HTTPS

All of this is done; it is written down because the certificate behaviour is
not what the Vercel UI implies.

Namecheap holds the domain and serves DNS from **BasicDNS**
(`dns1`/`dns2.registrar-servers.com`). The Web Hosting DNS nameservers
(`namecheaphosting.com`) lock the Advanced DNS tab and serve a parking page —
if the apex ever shows "Namecheap Parking Page" with `Server: LiteSpeed`, the
nameservers got switched back.

Current records, alongside the untouched `MX`/`TXT` rows that Private Email
needs:

| Type | Host | Value |
| --- | --- | --- |
| `A` | `@` | `76.76.21.21` |
| `CNAME` | `www` | `cname.vercel-dns.com` |
| `CNAME` | `play` | `cname.vercel-dns.com` |

Those work, but they are Vercel's **legacy** endpoints. `vercel domains verify
<domain>` ranks them second and now recommends two apex `A` records
(`216.198.79.1` and `64.29.17.1`) and a per-domain `CNAME`. Read the current
values out of that command rather than copying the table above.

### A domain added before DNS resolves will never get a certificate

Vercel issues certificates over ACME, which needs the hostname to already
resolve to Vercel. Add the domain first and the challenge fails, the domain
enters a long backoff, and nothing in the dashboard says so — the domain reads
as attached and verified, HTTP works, and HTTPS just refuses the handshake
forever. That is exactly what happened to the apex and `www` here.

```bash
npx vercel certs ls                      # a missing hostname means no certificate
npx vercel certs issue example.com www.example.com   # ~13s, breaks the backoff
```

So: point DNS first, confirm it resolves, *then* add the domain. If the order
slipped, `certs issue` is the repair.

### macOS caches DNS past the record's TTL

`dig` queries a resolver directly; `curl`, `openssl` and browsers go through
`mDNSResponder`, which held the old Namecheap address here long after every
public resolver had the new one. The symptom is a parking page or a stale site
that no amount of DNS checking explains. Diagnose with `dscacheutil -q host -a
name <domain>` — if it disagrees with `dig`, the cache is lying:

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

`dscacheutil -flushcache` on its own does not clear it. To check the real state
without touching the cache, pin the address instead:

```bash
curl -sSI --resolve example.com:443:76.76.21.21 https://example.com/
```

## Assets

The landing images under `web/landing/assets/` are compressed copies of
project-owned art; the source game assets stay in their own folders.
`web/.gdignore` keeps the whole web tree out of the Godot import pipeline, so
none of it is packed into the game.

# Web publishing

The public web presence is deliberately split into two Vercel projects so the
small portfolio site stays fast and the Godot Web export can be deployed and
rolled back independently.

| Hostname | Vercel root directory | Purpose |
| --- | --- | --- |
| `shadowcastledetective.com` | `web/landing` | Official game and portfolio site |
| `www.shadowcastledetective.com` | Redirect to the apex domain | Canonical-domain redirect |
| `play.shadowcastledetective.com` | Generated Godot Web export | Browser-playable game |

## Landing site

`web/landing` is a dependency-free static site. Its images are compressed copies
of project-owned art and visual-test captures; the source game assets remain in
their existing folders. Configure the Vercel project with framework preset
**Other**, root directory `web/landing`, and no build command.

## Game site

Create the Godot Web export as a single-threaded build with the Compatibility
renderer. Deploy the generated HTML, JavaScript, WebAssembly, and PCK files to a
separate Vercel project, then attach `play.shadowcastledetective.com` to it.
Keeping the game separate avoids making every portfolio-text change re-upload the
large game payload.

## DNS ownership

Namecheap remains the registrar and DNS owner. Use the exact A/CNAME targets
shown by Vercel after each custom domain is attached. Preserve any MX and TXT
records used for email or domain verification.

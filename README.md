
The Sonos desktop app for macOS 17.2.3 (build `90.0.79210`) can show a false
“Your computer’s firewall setting has changed” screen on macOS Tahoe and later,
even when the firewall is disabled and the speakers are reachable.

This script creates a patched copy of the app which bypasses only the faulty
Tahoe-specific check. It does not modify `/Applications/Sonos.app`.

## Note

This is AI generated, but I hope this helps for someone.

## What it changes

The affected app contains a method named
`shouldShowTahoeS1FirewallMessage`. This script replaces that method with a
constant `false` return in both the Intel and Apple-silicon executable slices.
The copied bundle is then ad-hoc signed locally so macOS can run it.

It is intentionally limited to the exact app version above and verifies the
expected machine-code bytes before writing. If Sonos releases a different app
build, the script exits instead of guessing.

## Use

1. Download or clone this repository.
2. In Terminal, run:

   ```sh
   chmod +x sonos-tahoe-firewall-patch.sh
   ./sonos-tahoe-firewall-patch.sh
   ```

3. Quit Sonos, then open `~/Applications/Sonos Patched.app`.

The original app remains at `/Applications/Sonos.app` and is not changed.

To use a non-default source app or destination:

```sh
./sonos-tahoe-firewall-patch.sh \
  "/Applications/Sonos.app" \
  "$HOME/Applications/Sonos Patched.app"
```

## Requirements

- macOS with the standard developer command-line tools available (`ditto`,
  `lipo`, `codesign`, `plutil`, `xxd`, and `dd`).
- Sonos desktop app 17.2.3, build 90.0.79210.

## Caveats

- This is an unofficial, local workaround—not an update from Sonos.
- The patched copy is ad-hoc signed, so it will not retain Sonos’s vendor
  signature or receive automatic app updates.
- Do not run this script against another Sonos version. It is designed to fail
  safely in that case.

## Why this exists

The app's own “Configure Firewall” action only displays obsolete instructions.
In the affected case, the Mac firewall and local Sonos networking work; the app
blocks itself before it connects. This patch removes that incorrect block and
leaves normal Sonos discovery and connections unchanged.

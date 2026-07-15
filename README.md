# TuskUpLoot

World of Warcraft addon for **TBC Classic Anniversary** (`Interface 20505`). Guild raid loot catalog, sixtyupgrades BIS import, and need tracking for your roster.

## Features

- Import BIS gear sets from sixtyupgrades JSON
- **Characters** — gear sets per character, acquired toggles, class-colored summary
- **Items** — who still needs each piece; mark acquired
- **Raids** — instance loot, need counts, boss clear tracking (per raid run)
- **Opts** — toggle raid loot chat announcements and debug messaging

## Install

1. Install from [CurseForge](https://www.curseforge.com/wow/addons) (when published), or download `TuskUpLoot.zip` from [GitHub Releases](https://github.com/keithvsr/TuskUpLoot/releases).
2. Extract the `TuskUpLoot` folder into your WoW AddOns directory, e.g. `_anniversary_/Interface/AddOns/`.
3. Enable the addon on the character select screen and `/reload` in game.

## Usage

- Open the window: `/tul` or `/tuskup`
- Import a character list: **Import JSON** (sixtyupgrades export paste)

## License

Copyright (c) 2026 Kaaser-Nightslayer. **All Rights Reserved.**

See [LICENSE](LICENSE) for terms. You may download and use from official distribution channels (e.g. CurseForge). Redistribution or modified distribution requires written permission.

## Build (local)

```bash
./build.sh
```

Output: `dist/TuskUpLoot/` and `dist/TuskUpLoot.zip`.

The packaged toc substitutes `@project-version@` with `dev` by default. Override for a test build:

```bash
TUSKUPLOOT_VERSION=1.0.0 ./build.sh
```

## Releases

Version in the distributed addon comes from the **git tag** via the [BigWigs packager](https://github.com/BigWigsMods/packager). The source toc uses:

```toc
## Version: @project-version@
```

**Release steps:**

1. Update [CHANGELOG.md](CHANGELOG.md).
2. Commit and push.
3. Tag and push: `git tag v1.0.0 && git push origin v1.0.0`
4. GitHub Actions builds the zip and attaches it to the GitHub Release for that tag.
5. On CurseForge: set project license to **All Rights Reserved**, link GitHub releases or upload the release zip.

Use tags like `v1.0.0`, `v1.0.1` — the packaged `## Version:` field matches the tag name.

**Optional:** Add `CF_API_KEY` and `curse-project-id` in `.pkgmeta` for automatic CurseForge uploads.

## CurseForge checklist

1. Create project; license **All Rights Reserved** (matches [LICENSE](LICENSE)).
2. Game/flavor: WoW Classic / TBC Anniversary; `## Interface: 20505`.
3. Connect GitHub or upload the latest release `TuskUpLoot.zip`.
4. Description: mention `/tul` and BIS import.

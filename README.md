# Batomon Showdown — Leaderboard Mod

Adds a leaderboard panel to the title screen showing your ranked tier, MMR, win rate, and the Master-tier leaderboard fetched from the game's backend.

## Requirements

- [Batomon Showdown Demo](https://store.steampowered.com/app/4557380) installed on Steam
- Windows 7+ (.NET Framework 4.x built-in)
- Some GPUs need `--rendering-driver opengl3` (the included launcher handles this)

## Installation

1. Download the latest release from [Releases](https://github.com/darkred1145/batomon-showdown-leaderboard-mod/releases) and extract the zip
2. Run `Leaderboard Mod Installer.exe`
3. It copies the game from your Steam install, patches the PCK with mod files, and places everything on your desktop
4. Launch from `Desktop\Batomon Showdown Leaderboard\Leaderboard Mod Launcher.exe`

The original Steam install is never modified. Only your source files (`.gd`, `.tscn`) are distributed — the game's copyrighted PCK is patched locally from your own copy.

## Building from source

Requires [GodotPCKExplorer](https://github.com/DmitriySalnikov/GodotPCKExplorer) (included at `_tools/pckexplorer/` after installing the demo).

```powershell
# One-time: back up the original PCK
copy "$gameDir\batomon_showdown.pck" "$gameDir\batomon_showdown.pck.orig"

# One-time: create .env with your PCK key (see .env.example)
copy .env.example .env
# then edit .env and paste your key

# Build mod PCK (patches .pck with src/ files)
.\tools\build_mod.ps1

# (Optional) Rebuild installer/launcher
$key = ((Get-Content .env) -match "^PCK_KEY=") -split "=",2 |% { $_[1].Trim() }
$src = (Get-Content tools\installer_source.cs -Raw) -replace "PCK_KEY_PLACEHOLDER", $key
$src | Set-Content "$env:TEMP\installer.cs" -Encoding ASCII
csc /target:exe /out:"tools\Leaderboard Mod Installer.exe" "$env:TEMP\installer.cs"
csc /target:winexe /reference:System.Windows.Forms.dll /out:"tools\Leaderboard Mod Launcher.exe" tools\launcher_source.cs
```

**Note:** `.env` is gitignored — your PCK key stays local. Never commit it to the repo.
A pre-commit hook (`.githooks/pre-commit`) automatically blocks any commit containing the key. Enable it with:
```powershell
git config core.hooksPath .githooks
```

## Project structure

```
├── src/                           # Mod source files (GDScript, scenes)
│   ├── game/
│   │   ├── states/
│   │   │   ├── title_state.gd               # Adds Leaderboard button to title
│   │   │   └── title_state.tscn.remap        # Scene redirect
│   │   └── ui/common/
│   │       ├── leaderboard_panel.gd          # Panel logic, layout, leaderboard fetch
│   │       ├── leaderboard_panel.tscn        # Scene source (Godot editor)
│   │       └── leaderboard_panel.tscn.remap  # Scene redirect
│   └── .godot/exported/.../
│       └── export-*leaderboard_panel.scn     # Compiled scene
├── tools/
│   ├── installer_source.cs                   # Installer source (C#)
│   ├── launcher_source.cs                    # Launcher source (C#)
│   ├── Leaderboard Mod Installer.exe         # Compiled installer
│   ├── Leaderboard Mod Launcher.exe          # Compiled launcher
│   └── build_mod.ps1                         # Local PCK build script
├── .env                        # Local PCK key (gitignored)
├── .env.example                 # Template for .env
├── .gitignore
├── LICENSE
└── README.md
```

The release zip bundles `Leaderboard Mod Installer.exe`, `Leaderboard Mod Launcher.exe`, `GodotPCKExplorer.Console.exe`, `mbedTLS/`, and `mod_files/` (a copy of `src/`). The installer patches the game's PCK locally — no copyrighted assets are distributed.

## Features

- **Leaderboard button** on the title screen
- **User stats**: ranked tier, division, stars, MMR, win rate
- **Master-tier leaderboard**: top 200 players sorted by MMR
- **Animations**: fade-in/fade-out
- **Non-invasive**: standalone copy, original game untouched

## License

MIT — see [LICENSE](LICENSE).

*Batomon Showdown is the property of its respective owners. This mod is not affiliated with or endorsed by the game developers.*

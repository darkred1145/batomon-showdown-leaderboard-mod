# Batomon Showdown — Leaderboard Mod

Adds a centered leaderboard overlay to the title screen.

## What it does

Shows your ranked leaderboard position, win rate, and top entries directly from the title screen — no need to navigate menus.

## Requirements

- [Batomon Showdown Demo](https://store.steampowered.com/app/4557380) installed on Steam
- Windows 7+ (.NET Framework 4.x built-in)

## Installation

1. Download the latest `Leaderboard Mod Installer.exe` from [Releases](https://github.com/darkred1145/batomon-showdown-leaderboard-mod/releases)
2. Place it anywhere (keep `batomon_showdown.pck` next to it)
3. Run `Leaderboard Mod Installer.exe` — it creates `Desktop\Batomon Showdown Leaderboard\`
4. Launch from `Desktop\Batomon Showdown Leaderboard\Leaderboard Mod Launcher.exe`

The original Steam install is never modified.

## Building from source

You'll need:
- [GodotPCKExplorer](https://github.com/ValveSoftware/GodotPCKExplorer) for PCK patching
- The PCK encryption key (extracted from `batomon_showdown.exe`)

See `tools/build_mod.ps1` for the automated build process.

## Project structure

```
├── src/
│   ├── game/ui/common/leaderboard_panel.gd    # Main panel logic
│   ├── game/states/title_state.gd             # Modified title state
│   ├── .godot/exported/.../*.scn              # Compiled scene
│   └── *.tscn.remap                           # Scene redirect files
├── tools/
│   ├── installer_source.cs                    # Installer EXE source
│   ├── launcher_source.cs                     # Game launcher EXE source
│   └── build_mod.ps1                          # Automated build script
├── .gitignore
└── LICENSE
```

## License

MIT — see [LICENSE](LICENSE).

*Batomon Showdown is the property of its respective owners. This mod is not affiliated with or endorsed by the game developers.*

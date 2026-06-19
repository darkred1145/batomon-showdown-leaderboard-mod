# Contributing

## Reporting bugs

Open an [issue](https://github.com/darkred1145/batomon-showdown-leaderboard-mod/issues) with:

- Steps to reproduce
- What you expected vs what happened
- Screenshots if applicable

## Feature requests

Open an issue with a clear description of what you want and why.

## Pull requests

1. Fork the repo
2. Create a feature branch
3. Test your changes
4. Open a PR against `master`

## Code style

- GDScript: match the existing style — no type inference (`:=`) on Variant properties
- C#: keep it compatible with C# 5 (no string interpolation, no `using var`)
- No PCK encryption key in source files — use `PCK_KEY_PLACEHOLDER` and build with `.env`

## Security

See `SECURITY.md` for reporting sensitive issues.

# Critical: PCK Encryption Key

The game's PCK encryption key MUST **NEVER** appear in:

- Any file tracked by git
- Commit messages
- GitHub issues, PRs, or comments
- Release descriptions

## Rules

1. **`installer_source.cs`** must always contain the placeholder `PCK_KEY_PLACEHOLDER` — never the real key
2. **`build_mod.ps1`** reads the key from `.env` at build time — never hardcode it
3. The real key lives only in `.env` (gitignored, never committed)
4. A pre-commit hook (`.githooks/pre-commit`) blocks commits that contain the key pattern — do not bypass it


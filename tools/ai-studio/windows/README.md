# AI Studio (Windows)

Release artifacts for Revolution Macro's AI Gather → AI Studio installer.

| File | Purpose |
|------|---------|
| `ai-studio.exe` | Editor binary |
| `ai-studio.version` | Uppercase SHA-256 hex of `ai-studio.exe` (update check sidecar) |
| `ai-studio.release.json` | Semver + `minRevolutionVersion` + `minProfileVersion` + `sha256` |

CDN path (primary): `https://cdn.revolutionmacro.com/tools/ai-studio/windows/`

GitHub backup: `https://raw.githubusercontent.com/nosyliam/revolution-macro/main/tools/ai-studio/windows/`

`versions.manifest` at the repo root must include:

- `hashes["tools/ai-studio/windows/ai-studio.exe"]` — same value as `ai-studio.version`
- `versions["tools/ai-studio"]` — semver label (e.g. `0.2.0`)

Published from the **AI Studio** repo (`ai-configuration`) via `scripts/sync-revolution-macro.py` after `scripts/release.ps1`. See `docs/41-release.md` in that repository.

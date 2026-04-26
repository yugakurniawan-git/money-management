# Money Management App

Aplikasi keuangan keluarga berbasis Flutter Web.

## Tech Stack
- **Framework**: Flutter Web (dart2js, bukan WASM)
- **Backend**: Firebase (Firestore + Auth)
- **State Management**: Riverpod
- **AI**: OpenAI GPT-4o untuk scan struk (via `--dart-define=OPENAI_API_KEY`)
- **Deploy**: GitHub Actions → Coolify (Unmanaged VPS, Novacloud) — bukan cPanel lagi

## Struktur Penting
- `lib/services/firebase_service.dart` — semua operasi Firestore
- `lib/services/ai_receipt_service.dart` — scan struk via OpenAI Vision
- `lib/providers/` — Riverpod providers
- `lib/screens/` — UI screens
- `web/index.html` — entry point PWA
- `.github/workflows/deploy.yml` — CI/CD pipeline

## Konvensi
- Gunakan `ConsumerStatefulWidget` / `ConsumerWidget` untuk screen yang butuh provider
- API key OpenAI di-pass via `--dart-define`, bukan file `.env`
- Transaksi punya field wajib: `accountId`, `importHash`, `transactionDate`, `transactionType`

## Workflow Wajib
- **Setelah setiap edit file, langsung commit dan push ke GitHub** — tanpa perlu disuruh.
  Coolify otomatis deploy dari `main` setiap ada push baru.

## Hal yang Tidak Perlu Dilakukan
- Jangan tambah dependency baru tanpa perlu
- Jangan buat file dokumentasi kecuali diminta
- Jangan refactor kode yang tidak terkait task

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **money-management** (406 symbols, 485 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/money-management/context` | Codebase overview, check index freshness |
| `gitnexus://repo/money-management/clusters` | All functional areas |
| `gitnexus://repo/money-management/processes` | All execution flows |
| `gitnexus://repo/money-management/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

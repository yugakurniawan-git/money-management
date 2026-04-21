# Money Management App

Aplikasi keuangan keluarga berbasis Flutter Web.

## Tech Stack
- **Framework**: Flutter Web (dart2js, bukan WASM)
- **Backend**: Firebase (Firestore + Auth)
- **State Management**: Riverpod
- **AI**: OpenAI GPT-4o untuk scan struk (via `--dart-define=OPENAI_API_KEY`)
- **Deploy**: GitHub Actions → FTP → cPanel (`management.yugakurniawan.com`)

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

## Hal yang Tidak Perlu Dilakukan
- Jangan tambah dependency baru tanpa perlu
- Jangan buat file dokumentasi kecuali diminta
- Jangan refactor kode yang tidak terkait task

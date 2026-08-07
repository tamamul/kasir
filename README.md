# Kasir Flutter — client mobile untuk backend Apps Script

Client Flutter yang manggil langsung backend Apps Script yang sama dengan
versi web (bukan lewat proxy PHP — mobile app boleh panggil langsung).
Google Sheets tetap satu-satunya database.

## Cara jalanin

1. Pastikan sudah punya Flutter SDK terpasang (`flutter --version` untuk cek).
2. Taruh folder ini di mana saja, lalu dari terminal:
   ```
   cd kasir_flutter
   flutter pub get
   ```
3. Edit `lib/config.dart`, ganti `appsScriptUrl` dengan URL deployment Apps
   Script kamu (yang sama persis dipakai di `config.php` versi web).
4. Jalankan ke device/emulator:
   ```
   flutter run
   ```
5. Login pakai akun yang sudah ada (misal `admin` dari setupDatabase(), atau
   akun kasir yang sudah kamu buat lewat versi web).

## Build APK buat testing di HP

```
flutter build apk --release
```
Hasilnya ada di `build/app/outputs/flutter-apk/app-release.apk`, tinggal
kirim/install manual ke HP Android buat testing.

## Struktur

- `lib/config.dart` — URL Apps Script
- `lib/services/api_client.dart` — HTTP client ke Apps Script. Ada penanganan
  manual untuk redirect 301/302/303 (Apps Script kadang redirect ke
  googleusercontent.com), supaya method POST + body JSON tidak hilang saat
  diikuti otomatis oleh package http.
- `lib/services/auth_service.dart` — state login/token/role global (pakai
  provider), token disimpan di shared_preferences supaya tidak perlu login
  ulang tiap buka app (sampai token 6 jam kedaluwarsa).
- `lib/screens/` — satu file per layar: kasir (POS), produk, kategori,
  pelanggan, pembelian (stok masuk), laporan, users & pengaturan (admin only,
  otomatis disembunyikan dari drawer kalau login sebagai kasir biasa).

## Kalau ada error response tidak valid / HTML kebalik dari JSON

Kemungkinan besar deployment Apps Script belum di-set "Who has access: Anyone".
Cek lagi di Apps Script: Deploy > Manage deployments > edit > pastikan
"Anyone" (bukan "Anyone with Google account" atau "Only myself"), lalu deploy
ulang versi barunya.

## Tahap berikutnya (belum termasuk di sini)

- Icon & nama app (ganti di `android/app/src/main/AndroidManifest.xml` dan
  `pubspec.yaml`, atau pakai package `flutter_launcher_icons`).
- Print struk ke printer bluetooth/thermal (kalau nanti butuh cetak fisik).
- Scan barcode pakai kamera (sekarang field pencarian mengasumsikan scanner
  eksternal/keyboard-emulation; kalau mau pakai kamera HP, tinggal tambah
  package seperti `mobile_scanner`).

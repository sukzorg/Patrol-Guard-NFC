# Product Requirement Document (PRD)

## Aplikasi Patrol Guard berbasis NFC

---

## 1. Latar Belakang

Banyak sistem patroli keamanan masih dilakukan secara manual sehingga:

- Tidak ada bukti valid bahwa petugas benar-benar mengunjungi titik patroli
- Sulit melakukan monitoring real-time
- Rawan manipulasi laporan

Solusi: membangun aplikasi patrol guard berbasis **NFC (Near Field Communication)** untuk mencatat aktivitas patroli secara otomatis, akurat, dan terintegrasi.

---

## 2. Tujuan Produk

- Mencatat aktivitas patroli security secara digital
- Memastikan checkpoint patroli benar-benar dikunjungi
- Menyediakan histori dan laporan patroli
- Memungkinkan sistem tetap berjalan saat offline
- Memberikan monitoring kepada supervisor

---

## 3. Stakeholder

- Security Guard (User utama)
- Supervisor
- Admin sistem
- Manajemen gedung

---

## 4. Scope Produk (MVP)

### In Scope

- Login user
- Scan NFC untuk checkpoint
- Penyimpanan log patroli
- Mode offline (SQLite)
- Sinkronisasi ke server (MySQL)
- Dashboard monitoring sederhana

### Out of Scope (fase awal)

- Integrasi CCTV
- AI behavior tracking
- Multi-tenant enterprise kompleks

---

## 5. Arsitektur Sistem

### Mobile App (Flutter)

- NFC scanning
- Local database (SQLite)
- Offline-first storage
- Sync ke backend

### Backend (Laravel)

- REST API
- Validasi data
- Sinkronisasi
- Reporting

### Database

- SQLite (local device)
- MySQL (server)

---

## 6. Konsep Offline-First

### Prinsip

- Semua data disimpan ke SQLite terlebih dahulu
- Data dikirim ke server saat koneksi tersedia

### Status Data

- `pending`
- `synced`
- `failed`

---

## 7. User Flow

### 7.1 Login

1. User login
2. Sistem menyimpan session

### 7.2 Mulai Patroli

1. User pilih shift
2. Sistem membuat patrol session

### 7.3 Scan NFC

1. User scan NFC
2. App membaca UID
3. Data disimpan ke SQLite
4. Jika online → kirim ke server
5. Jika offline → tandai pending

### 7.4 Sinkronisasi

1. App cek koneksi
2. Ambil data pending
3. Kirim ke API
4. Update status menjadi synced

### 7.5 Monitoring

- Supervisor melihat dashboard
- Melihat status patroli

---

## 8. Data Model

### 8.1 Users

- id
- name
- email
- role

### 8.2 Checkpoints

- id
- building_id
- name
- nfc_uid

### 8.3 Patrol Sessions

- id
- guard_id
- start_time
- end_time

### 8.4 Patrol Logs

- id
- local_uuid
- checkpoint_id
- scanned_at
- sync_status

---

## 9. API Endpoint

### Auth

- POST /login

### Patrol

- POST /patrol/start
- POST /patrol/scan
- POST /patrol/sync
- POST /patrol/end

### Master Data

- GET /checkpoints

---

## 10. Non-Functional Requirements

### Performance

- Scan NFC < 2 detik

### Reliability

- Tidak boleh kehilangan data saat offline

### Security

- Authentication required
- Data validation di backend

### Compatibility

- Fokus Android (NFC support)

---

## 11. Risiko

- Tidak semua device support NFC
- Sinyal internet tidak stabil
- Duplikasi data saat sync

Mitigasi:

- Gunakan UUID
- Retry mechanism
- Offline storage

---

## 12. Future Enhancement

- GPS tracking
- Foto bukti
- Notifikasi real-time
- Analytics patrol performance

---

## 13. Success Metrics

- 100% checkpoint tercatat
- Penurunan manipulasi laporan
- Waktu patroli lebih terukur

---

## 14. Timeline (Estimasi)

### Phase 1 (MVP)

- 4–6 minggu

### Phase 2

- 4 minggu

---

## 15. Teknologi Stack

- Flutter
- Laravel
- MySQL
- SQLite

---

## 16. Kesimpulan

Aplikasi patrol guard berbasis NFC memungkinkan digitalisasi proses patroli dengan akurasi tinggi dan dukungan offline, sehingga meningkatkan keamanan dan transparansi operasional.

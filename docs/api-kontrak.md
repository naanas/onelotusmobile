# Kontrak API One Lotus Mobile (staf & pasien)

> **Status: diimplementasikan** di backend Go (`backend/internal/mobile`, schema `mobile` —
> `supabase/migrations/003_mobile_schema.sql` + `004_mobile_flow.sql`). Bagian "Alur kasir, owner & pasien"
> di bawah ditambahkan 9 Okt 2026 mengikuti layar yang sudah di-slicing; aplikasi belum memanggilnya (masih data contoh). Disusun dari kebutuhan aplikasi
> (`lib/data/remote/http_remote.dart`, `lib/data/auth/api_auth_repository.dart`). Bila backend memilih bentuk
> lain, cukup ubah dua file itu — layar & repository tidak perlu berubah.

## Umum

- Base URL dari build: `flutter run --dart-define=API_URL=https://…` (kosong = mode mock di HP).
- Prefix `/v1`. JSON, `snake_case`, tanggal ISO-8601 UTC (`2026-10-06T03:30:00Z`), tanggal lahir `YYYY-MM-DD`.
- Uang dalam rupiah, bilangan bulat (`450000`).
- Auth: Laravel Sanctum, header `Authorization: Bearer <token>`. Header `X-App-Version` dikirim tiap request.
- Respons resource dibungkus `{ "data": … }` (Laravel API Resource). Daftar berhalaman: `per_page=20`, `page=n`.
- Timeout aplikasi 15 detik.

### Format error (spec §12.7)

```json
{ "code": "validation", "message": "…", "errors": { "weight_kg": ["Berat badan harus angka, mis. 58"] }, "ref": "OL-7F3A" }
```

| HTTP | `code` | Aplikasi |
|---|---|---|
| 401 | — | Sesi berakhir (ST-15), data lokal tetap aman |
| 403 | `forbidden` | Toast |
| 404 | `not_found` | Layar error di area konten |
| 409 | `edit_conflict` + `server` | Pilih versi (ST-09) |
| 409 | `duplicate_patient` | Bottom sheet pasien ganda |
| 422 | `validation` + `errors` | Pesan per field (sebaiknya sudah dalam bahasa §12.3) |
| 429 | `rate_limited` | Toast info |
| 5xx | `server_error` | Toast + `ref`, outbox mencoba ulang otomatis |

`ref` juga boleh dikirim di header `X-Request-Ref`.

## Auth & aplikasi

| Method | Path | Body / query | Respons `data` |
|---|---|---|---|
| GET | `/v1/app/status` | — | `{ min_version, maintenance, maintenance_until }` |
| POST | `/v1/auth/login` | `{ username, password, device_name }` | `{ token, user }` |
| POST | `/v1/auth/password` | `{ current_password, password }` | — |
| POST | `/v1/auth/password-reset-requests` | `{ username, note }` | — (selalu 202, juga untuk username tak terdaftar — UM-06) |
| POST | `/v1/auth/logout` | — | — |

`user`: `{ id, username, name, roles: ["terapis","kasir","owner"], branches: [{ id, name, address }], must_change_password }`.
Login gagal → 401/422 (pesan tidak membedakan username/password). Akun nonaktif → `code: "account_disabled"`.
Penguncian 5× gagal sebaiknya juga ditegakkan di server.

## Jadwal & sesi

| Method | Path | Keterangan |
|---|---|---|
| GET | `/v1/sessions?branch_id=&from=&to=&therapist_id=` | Daftar sesi rentang waktu, urut `start_at` |
| PATCH | `/v1/sessions/{id}/status` | `{ status, at, reason? }` — dikirim lewat outbox, bisa terlambat (offline) |
| POST | `/v1/sessions/{id}/reschedule-requests` | `{ reason, proposal?, at }` — terapis minta pindah jadwal, notifikasi ke front desk (TR-01) |

Sesi: `{ id, patient_id, patient_name, patient_number, therapist_id, therapist_name, service_id, service_name,
branch_id, start_at, duration_min, status, room, home_visit: { address, landmark, distance_km, lat, lng } | null,
is_new_patient, note, arrived_at, started_at, ended_at, source, needs_action }`.
`source` ∈ `front_desk, walk_in, app, website`; `needs_action` = sesi terdampak pindah massal yang belum dapat pengganti (KS-08).

`status` ∈ `awaiting_confirmation, scheduled, arrived, running, done, unpaid, paid, no_show, cancelled` (§6.2).
Karena dikirim dari outbox, server memakai `at` dari HP sebagai waktu kejadian, bukan waktu terima.

**Perpindahan status yang sah** (diperiksa server; selain ini → 422 `errors.status`):

| Dari | Ke | Siapa |
|---|---|---|
| awaiting_confirmation | scheduled (Terima) · cancelled (Tolak) | kasir, owner |
| scheduled | arrived | terapis (sesinya), kasir, owner |
| scheduled | running | terapis — **hanya home visit** (check-in di lokasi) |
| scheduled / arrived | no_show | terapis (sesinya), kasir, owner |
| scheduled / arrived | cancelled | kasir, owner |
| arrived | running | terapis (sesinya); hanya 1 sesi berjalan per terapis |
| running | done | terapis (sesinya) → tagihan Draft dibuat otomatis |
| done → unpaid / paid, unpaid → paid | | kasir, owner (sementara, sampai modul bayar Fase 2) |

- Kirim ulang status yang sama → 200 tanpa perubahan (outbox idempoten).
- `at` lebih tua dari perubahan status terakhir di server → 422 (`Status sesi sudah diubah lebih dulu…`).
- Alasan wajib untuk `no_show` & `cancelled`. Setiap perpindahan tercatat di `mobile.audit_log`.

## Pasien

| Method | Path | Keterangan |
|---|---|---|
| GET | `/v1/patients?q=&page=&per_page=20&scope=mine` | `q` = nama / nomor (`0412`) / 4 digit akhir HP. `scope=mine` = pasien yang pernah ditangani terapis login (TR-06) |
| GET | `/v1/patients/{id}` | Detail |
| GET | `/v1/patients/{id}/records?page=` | Riwayat rekam sesi, terbaru dulu |
| GET | `/v1/patients/{id}/legacy-records` | Catatan sistem lama apa adanya: `[{ date, fields: { "Keluhan": "…", … } }]` |

Pasien: `{ id, number, name, birth_date, birth_place, phone, address, gender: "L"|"P", institution, hobby,
height_cm, weight_kg, medical_alert, active_package: { name, remaining, total, expires_at } | null, last_visit_at }`.
**`phone` & `address` dikirim `null` bila peran tidak berwenang** (§7, §10) — penyaringan di server, bukan di HP.

## Rekam sesi (TR-04)

| Method | Path | Keterangan |
|---|---|---|
| GET | `/v1/sessions/{id}/record` | 404 bila belum ada |
| PUT | `/v1/session-records/{id}` | Upsert idempoten. `id` dibuat di HP (UUID) agar bisa disimpan offline |

Body PUT = objek rekam sesi + `base_version`:

```json
{ "id": "6f1c…", "session_id": "s2", "patient_id": "p0412", "therapist_id": "u1",
  "complaint": "…", "cause": "kerja", "cause_note": null, "injury_duration": 3, "injury_duration_unit": "month",
  "treated_areas": ["lower-back:left", "deltoids:right"], "calming_areas": ["upper-back:left"],
  "pain_before": 7, "pain_after": 3, "analysis": "…", "analysis_tags": ["Spasme otot"],
  "treatments": ["Adjustment"], "treatment_note": "", "conclusion": "…", "conclusion_tags": [],
  "attachments": [], "updated_at": "…", "base_version": 1 }
```

- Area tubuh = `slug:sisi` dari `assets/body/_parts.json` (sisi pasien).
- Pemetaan kolom lama `perawatan` → field baru: spec Lampiran A.2.
- **Versi & konflik (§8.4):** server menyimpan `version`. Bila `base_version` < versi server → **409**
  `{ "code": "edit_conflict", "server": { …rekam sesi versi server, termasuk version } }`. Sukses → 200 dengan
  rekam sesi tersimpan (`version` baru). Untuk catatan medis aplikasi tidak menimpa otomatis; terapis memilih.
- Lampiran (foto, rontgen, suara) diunggah terpisah — endpoint menyusul saat AttachmentRow dibangun.

## Layanan & tagihan

| Method | Path | Keterangan |
|---|---|---|
| GET | `/v1/services?branch_id=` | `[{ id, name, duration_min, price }]` |
| GET | `/v1/sessions/{id}/invoice` | 404 bila belum ada tagihan |

Tagihan: `{ id, session_id, patient_id, items: [{ label, amount }], adjustments: [{ kind: member|voucher|manual|points,
label, amount, reason }], status, total, paid_amount, paid_at }`. `total` dihitung server (sumber kebenaran);
aturan diskon/komisi/paket menunggu workshop (§16).

---

## Alur kasir, owner & pasien (ditambahkan 9 Okt 2026)

Semua error aturan bisnis memakai 422 `validation` dengan pesan di field terkait, jadi aplikasi cukup
menampilkannya inline/toast. Peran: **desk** = kasir atau owner.

### Jadwal & antrian (KS-01, KS-06, KS-08, OW-02)

| Method | Path | Siapa | Keterangan |
|---|---|---|---|
| GET | `/v1/branches/{id}` | staf cabang | `{ id, name, address, opening_hours, wa_number, rooms }` |
| GET | `/v1/branches/{id}/rooms` | staf cabang | `[{ id, name, capacity }]` |
| GET | `/v1/branches/{id}/therapists?date=` | desk | `[{ id, name, available?, unavailable_reason? }]` — `available=false` bila cuti seharian |
| GET | `/v1/slots?branch_id=&date=&service_id=&therapist_id=&room=&exclude_session_id=&step=60` | desk | `[{ start_at, end_at, available, unavailable_reason, therapist_ids }]`. Dihitung dari jam operasional cabang, durasi layanan, sesi aktif, cuti disetujui, blok tidak tersedia, dan ruang. Alasan: `Penuh`, `Cuti`, `Tidak tersedia`, `Ruang terpakai`, `Lewat` |
| POST | `/v1/sessions` | desk | `{ patient_id, service_id, branch_id, therapist_id?, start_at, room?, home_visit?, note?, walk_in? }` → 201 sesi. `therapist_id` kosong = "siapa saja" (dipilih yang paling sedikit sesinya). `walk_in: true` → langsung Hadir, `start_at` default sekarang |
| PATCH | `/v1/sessions/{id}` | desk | Ubah sebagian: `start_at, therapist_id, service_id, room ("" = hapus), home_visit, clear_home_visit, note, reason`. Jadwal lama disimpan di `mobile.session_changes`. Sesi Hadir hanya boleh ganti terapis/ruang/catatan |
| POST | `/v1/sessions/bulk-move` | desk | `{ reason, moves: [{ session_id, therapist_id?, start_at? }] }` (maks 50). Item tanpa terapis & jam → ditandai `needs_action`. Respons per item: `{ session_id, status: moved|needs_action|failed, errors?, session? }` |
| GET | `/v1/reschedule-requests?branch_id=&open=true` | desk | Permintaan pindah jadwal dari terapis (TR-01) |
| POST | `/v1/reschedule-requests/{id}/handle` | desk | `{ resolution: moved|kept|cancelled }` |

Bentrok dicegah dua lapis: pemeriksaan di API (pesan jelas) dan constraint `EXCLUDE` di database
(terapis & ruang tidak bisa punya dua sesi Dijadwalkan/Hadir/Berjalan yang bertumpuk). Booking
"Menunggu konfirmasi" belum mengunci slot; bentrok diperiksa saat diterima.

### Pasien (KS-03..05, OW-03)

| Method | Path | Siapa | Keterangan |
|---|---|---|---|
| GET | `/v1/patients?…&archived=&has_package=&away=&unpaid=` | staf | Filter KS-03. `archived` hanya owner; `unpaid` bukan untuk terapis |
| POST | `/v1/patients` | desk | Isian KS-04 (lihat di bawah) → 201 pasien. **Nomor pasien dibuat server** (advisory lock, bukan max+1 di HP) |
| PUT | `/v1/patients/{id}` | desk | Sama, nomor baca-saja; perubahan masuk audit log |
| POST | `/v1/patients/{id}/archive` | desk | Soft delete (`deleted_at` Laravel). Ditolak bila masih ada jadwal aktif |
| POST | `/v1/patients/{id}/restore` | owner | Pulihkan dari arsip |

Isian: `{ name*, birth_date*, gender* (L|P), phone*, birth_place, address, home_lat, home_lng, emergency_contact,
height_cm (50–250), weight_kg (2–300), institution, hobby, referral_source, initial_complaint, medical_alert,
health_consent* (pasien baru), confirm_not_duplicate }`.
Cek ganda (HP sama, atau nama + tanggal lahir sama) → **409** `duplicate_patient` dengan
`candidates: [{ id, number, name, birth_date, match: phone|name_birth_date }]`. Kirim ulang dengan
`confirm_not_duplicate: true` bila kasir memilih "tetap buat baru". Penggabungan data ganda (OW-03) belum ada.
Pasien kini juga punya `archived_at`.

### Ketersediaan terapis & persetujuan (TR-02, TR-03, OW-06)

| Method | Path | Siapa | Keterangan |
|---|---|---|---|
| GET | `/v1/therapist-blocks?therapist_id=` | terapis (miliknya), desk (satu cabang) | Blok tidak tersedia |
| POST | `/v1/therapist-blocks` | terapis | `{ kind: once, starts_at, ends_at }` atau `{ kind: weekly, weekday (1=Senin…7), start_time, end_time }` + `note`. Bentrok dengan sesi → 422 berisi daftar sesi |
| DELETE | `/v1/therapist-blocks/{id}` | terapis | |
| GET | `/v1/leave-requests?status=&scope=mine` | staf | Terapis: miliknya; owner/kasir: terapis di cabangnya. Tiap item membawa `affected_sessions` |
| POST | `/v1/leave-requests` | terapis | `{ starts_at, ends_at, all_day, reason, note }` (tidak di masa lalu) |
| POST | `/v1/leave-requests/{id}/cancel` | terapis | Selama Menunggu |
| POST | `/v1/leave-requests/{id}/decision` | owner | `{ approve, reason }` (alasan wajib bila tolak) → `{ leave_request, affected_sessions }` untuk dipindah via bulk-move |
| GET | `/v1/password-reset-requests?open=true` | owner | Dari UM-06 |
| POST | `/v1/password-reset-requests/{id}/decision` | owner | `{ approve }` → `{ temporary_password }` (ditampilkan sekali; staf wajib ganti saat login, semua token dicabut) |

### Kelola staf & cabang (OW-08, OW-17 dasar) — owner

| Method | Path | Keterangan |
|---|---|---|
| GET | `/v1/staff` | `[{ …user, phone, is_active, last_login_at }]` |
| POST | `/v1/staff` | `{ name, username (4–30, huruf kecil/angka/titik), roles, branch_ids, phone }` → `{ user, temporary_password }`. Akun dibuat di `public.users` (dipakai bersama Laravel) |
| PUT | `/v1/staff/{id}` | `{ name, roles, branch_ids, phone }` |
| POST | `/v1/staff/{id}/activate` · `/deactivate` | Owner terakhir tidak bisa dinonaktifkan; terapis dengan sesi mendatang harus dipindah dulu |
| POST | `/v1/staff/{id}/reset-password` | → `{ temporary_password }` |
| POST | `/v1/staff/{id}/revoke-tokens` | Keluarkan dari semua perangkat |
| PUT | `/v1/branches/{id}` | `{ name, address, opening_hours: { "1": ["08:00","20:00"], … }, wa_number }` |
| POST | `/v1/branches/{id}/rooms` · PUT `/v1/branches/{id}/rooms/{room_id}` | `{ name, capacity, is_active }` |

### Pasien di aplikasi yang sama (UM-04 nomor HP, PS-02..04, PS-10, PS-20)

Token pasien terpisah dari token staf (token staf ditolak di `/v1/pasien/*` dan sebaliknya).
Nomor HP disimpan sebagai `62…`.

| Method | Path | Keterangan |
|---|---|---|
| POST | `/v1/pasien/otp` | `{ phone }` → 202 `{ resend_in: 60, expires_in: 300 }`. Kirim ulang ≥ 60 dtk, maks 5×/jam → 429 |
| POST | `/v1/pasien/otp/verify` | `{ phone, code, device_name }` → `{ token, account }`. Salah → 422 `errors.code`; salah 5× → 429, tunggu 15 menit |
| GET | `/v1/pasien/me` | `account` |
| GET | `/v1/pasien/link-candidates` | `{ candidates: [{ id, masked_name: "An** Pr*****" }], locked, attempts_left }` — pasien lama dengan HP sama |
| POST | `/v1/pasien/link` | `{ patient_id?, birth_date }` → `account`. Salah → 422 + sisa percobaan; gagal 3× → "Hubungi klinik" |
| POST | `/v1/pasien/register` | Isian seperti KS-04 (HP = nomor terverifikasi) → `account`. Data mirip pasien lain → 409 tanpa kandidat |
| POST | `/v1/pasien/consent` | `{ health*, reminder*, promo }` → `account` |
| GET | `/v1/pasien/sessions?scope=upcoming|past` | Jadwal saya (tanpa catatan internal). Butuh `next_step = ready` |
| POST | `/v1/pasien/logout` | |
| POST | `/v1/pasien/account/deletion-otp` → `/v1/pasien/account/deletion` `{ code }` | Permintaan hapus akun (PS-20); rekam medis tetap di klinik |

`account`: `{ id, phone, patient: Patient | null, consent: { health, reminder, promo, policy_version }, next_step }`.
`next_step` ∈ `link` → `consent` → `ready`, sama dengan `PasienPhase` di aplikasi. Versi kebijakan baru
(`MOBILE_POLICY_VERSION`) membuat `next_step` kembali ke `consent`.

**Pengiriman WhatsApp belum ada**: penyedia WA belum dipilih. Tanpa sender, `/v1/pasien/otp` menjawab 503;
`MOBILE_OTP_DEV_LOG=true` menulis kode ke log server untuk pengembangan.

### Intake pasien baru via QR (WB-01 di aplikasi → KS-02 → KS-04)

Formulir ada **di aplikasi** (satu aplikasi staf & pasien), tanpa login. QR di KS-02 berisi
`onelotus://app/intake/{kode}`: dipindai kamera HP → aplikasi terbuka di formulir; atau dipindai dari
layar masuk ("Pasien baru di klinik? Isi formulir"). Rute aplikasi: `/intake` (pemindai), `/intake/{kode}` (form).

| Method | Path | Siapa | Keterangan |
|---|---|---|---|
| GET | `/v1/public/intake/{kode}` | publik | `{ branch: { name, address }, policy_version }`; 404 = QR sudah tidak berlaku |
| POST | `/v1/public/intake/{kode}` | publik | Isian (lihat bawah) → 201 `{ queue_label: "A-07", first_name }`. Maks 10 kiriman/IP/jam; `client_id` sama = kiriman ulang aman |
| GET | `/v1/branches/{id}/intake-link` · POST `…/intake-link/rotate` | desk | `{ code, url }` — "Ganti QR" membuat kode lama langsung tidak berlaku |
| GET | `/v1/intake?branch_id=&status=new` | desk | "Baru masuk": `[{ id, queue_label, name, complaint, body_complete, attachment_count, status, stale (>24 jam), created_at }]` |
| GET | `/v1/intake/{id}` | desk | Isian lengkap + `attachments: [{ id, content_type, size_bytes }]` |
| GET | `/v1/intake/{id}/attachments/{att}` | desk | Gambar rontgen (tidak ada URL publik) |
| POST | `/v1/intake/{id}/process` | desk | Isian KS-04 hasil koreksi kasir → pasien baru (nomor dari server). 409 `duplicate_patient` + `candidates` → kirim ulang dengan `confirm_not_duplicate: true` atau `existing_patient_id` (gabung ke pasien lama) |
| POST | `/v1/intake/{id}/discard` | desk | `{ reason }` |

Isian form: `{ client_id (UUID dari HP), name*, birth_date*, gender*, phone*, birth_place, address, institution, hobby,
height_cm, weight_kg, complaint*, cause (olahraga|jatuh|kerja|kecelakaan|tidak_tahu), injury_duration,
injury_duration_unit (day|week|month), health_consent*, photos: [{ content_type, data (base64) }] maks 3 }`.
Data: `mobile.intake_submissions`, `mobile.intake_attachments` (`supabase/migrations/005_intake.sql`).

### Belum dibuat (menunggu workshop §16 / Fase 2–3)

Pembayaran & kas (KS-09..18: terbitkan tagihan, metode bayar, gateway, refund, tutup kas, piutang), paket &
voucher & poin, komisi, laporan & ekspor owner, booking oleh pasien (aturan auto-terima, DP, batas booking),
latihan rumah, notifikasi/WA ke pasien (termasuk kirim nomor pasien setelah intake diverifikasi), gabung pasien ganda, unggah lampiran rekam sesi.

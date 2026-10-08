# Kontrak API One Lotus — usulan dari aplikasi staf

> **Status: usulan**, belum disepakati dengan tim backend (Fase 0). Disusun dari kebutuhan aplikasi
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
is_new_patient, note, arrived_at, started_at, ended_at }`.

`status` ∈ `awaiting_confirmation, scheduled, arrived, running, done, unpaid, paid, no_show, cancelled` (§6.2).
Karena dikirim dari outbox, server memakai `at` dari HP sebagai waktu kejadian, bukan waktu terima.

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

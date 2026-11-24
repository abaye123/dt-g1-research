# WearPro <-> DT G1 capture #1 (2026-11-12)

Source: Android HCI snoop log (Samsung SM-A075F), pulled with `adb bugreport`,
file `FS/data/log/bt/btsnoop_hci.log`. The raw recordings held
private data and were deleted after decoding. Addresses and tokens are redacted.

The watch uses the same address for LE and BR/EDR.

## Big picture

- WearPro does NOT use the Glyphix MAS service (`e49a25f8-...`) for its own
  traffic. It only enables notifications there. Everything goes through a
  vendor service whose write/notify characteristic is ATT handle `0x0034`
  (128-bit UUIDs `...a111b958841727945746e6dfe08a0726` family).
- Bulk file transfer (custom background, 304,920 bytes) goes over
  **Bluetooth Classic SPP** (RFCOMM DLCI 20), same frame format.
- The watch is also an HFP hands-free device (RFCOMM DLCI 2, AT commands) and
  pulls message listings over MAP (DLCI 13). Not relevant for the studio.

## Frame format (both transports)

```
off size
0   1   magic: 0x55 phone->watch, 0xAA watch->phone
1   1   flags: 0x00 request, 0x10 response, 0x30 response (more?), 0x40 bulk (SPP)
2   2   seq (LE u16), echoed in the response
4   2   service (LE u16), e.g. 0x8001
6   2   command (LE u16)
8   2   checksum (LE u16, high byte 0) = CRC-8 of body
10  2   body length (LE u16)
12  n   body
```

CRC-8: poly 0x1D reflected (shift-right with 0xB8), init 0, xorout 0. Empty
body -> 0. Verified on all 154 BLE frames and all 470 SPP frames.
**No per-frame key or signature.**

Watch-initiated frames use seq 0 (e.g. `800e/0000`, `800c/0003`).
Keepalive: phone sends `beaf/0001` (empty) every 25 s.

## Authentication

Right after connecting (once per connection) the phone sends
`8000/0002` with a 32-byte body:

```
<20 bytes, redacted> 00000000 <8 bytes, redacted>
```

(20 bytes that look like a SHA-1, 4 zero bytes, 8 bytes). The watch answers
with an empty response. There was no challenge from the watch before it, so it
is either a static per-bond token or not validated. The watch does not enforce it
(see the PC test below).

## Commands seen

| svc/cmd | dir | body | meaning |
|---|---|---|---|
| 8000/0002 | P | 32 B | auth token (see above) |
| 8001/0000 | P | `0000` | ? (sync start) |
| 8001/0001 | P | `1a0b0c 170802 0000 0200 0e "Asia/Jerusalem"` | set time: yy mm dd hh mm ss, tz name |
| 8001/0003 | P | u32 5000 | step goal |
| 8001/0004 | P | 31 B incl. UTF-16 name | user profile |
| 8001/0005 | P | `0f3c00` | ? |
| 8001/000c | P | `000101` / `000000` | a toggle (user flipped a setting) |
| 8001/000d | P | 24 B, UTF-16 Hebrew city name | weather location / city |
| 8001/000f | P | 5 B | weather? |
| 8001/0010 | P | 18 B | weather forecast (daily min/max) |
| 8001/0012 | P | `"he-IL"` | language |
| 8001/0014 | P | 132 B text `token:...` | account token (private) |
| 8001/0016 | P | 140 B | weather hourly / detailed |
| 8001/0018 | P | 8 B | ? (timestamp-like) |
| 8002/0000 | P->W | -> 8 B | device info (`0150360afe580100`) |
| 8002/0002 | P->W | -> 76 B | settings snapshot (also pushed by watch after 8001/000c) |
| 8002/0003 | P->W | -> `6464` | battery (100) |
| 8002/0004 | P->W | -> `0101` | ? |
| 8002/0005 | P->W | -> `00` | ? |
| 8003/0011 | P->W | -> `019c02` | ? |
| 8004/0000..0003 | P->W | date `1a0b0a...` | health data pulls (daily records, 384 B tables) |
| 8004/000a | P->W | `03` -> 12 B | totals (steps etc.) |
| 8004/0014 | P->W | u32 timestamp | ? |
| 800e/0001 | P | `02` | ? |
| 800f/0000 | P->W | -> `dc070000` | ? |
| 8019/0000 | P->W | -> `0101` | ? |
| 8019/0002 | P->W | -> 32 B `"YZL\x04JLF\r..." + MAC` | YZL device identity |
| 8022/0000 | P (BLE) | `e7130000 3718` | file transfer prepare |
| 8022/0001 | P (BLE) | `11 "1794525007200.tmp"` | file name (watch answers `00`) |
| 8020/0000 | P (SPP) | `18a30400 d5010000 3718 0600 0000` | transfer header: size 304920, 469 chunks |
| 8020/0001 | P (SPP) | 656 B: 7 B chunk header + data | file chunk, watch acks every ~N |
| beaf/0001 | P | - | keepalive (25 s) |

## PC test (2026-11-12, verified)

With the phone's Bluetooth off, a Windows PC (Python `bleak`) connected to the
watch, enabled notify on characteristic `26078ae1-dfe6-4657-9427-178458b911a1`
(service `26078ae0-...`), and WITHOUT sending the `8000/0002` token got answers to
`8002/0003` (battery `6464`), `8002/0000` and `8019/0002`, and the write
`8001/0001` (set time) was acked. **The auth frame is not enforced.** MTU 247.

## Next steps

1. Wire a BLE client into the studio (time sync, weather, settings).
2. Second capture with a fresh pairing to see whether the 32-byte token changes.
3. Capture a watch-face switch (not clearly present in this capture).

## Weather (verified on the watch, 2026-11-13)

Sent by WearPro as four 8001 commands; all accepted from the PC.

- Icon codes (all weather commands): 0 sunny, 1 partly cloudy, 2 cloudy,
  3 rain, 4 snow; higher values fall back to sunny.
- 8001/0016 (detailed): header 13 B = icon, temp, min, max, feels-like,
  **UV index** (shown as a level: 5 moderate, 11 strong), ?, ?, ?, ?, 10, humidity, 20;
  then 7-day arrays (icon, min, max, precipitation %), 12-hour arrays (icon,
  temp, then 5 more arrays of unknown meaning: 0,0,0,10,45), then city
  (length byte + UTF-16LE). Temperatures are signed bytes.
- 8001/000d (summary): min, max, icon, temp, **humidity (displayed)**, ?, ?, 16, 42, city.
- 8001/0010: next 6 days as (min, max, icon).
- 8001/000f: 00, sea-level pressure*10 (u16 LE), unknown i16.
- 8001/0018: 8 bytes = longitude*1e6, latitude*1e6 (i32 LE), the phone's location.

## Capture #2 (2026-11-13, actions driven over adb)

| svc/cmd | body | meaning |
|---|---|---|
| 8003/0000 | - | find watch (vibrate) |
| 8001/0002 | 5 x `hour min days 01 enabled` | alarms; days bit0 = Monday .. bit6 = Sunday, 0 = once |
| 8002/0002 | -> 76 B | settings snapshot; first 25 B = alarm table |
| 8001/000c | `00 on on` | raise to wake |
| 8001/000a | `on sh sm eh em interval` | automatic heart rate (00:00-00:00 = all day) |
| 8001/0008 | `on sh sm eh em` | do not disturb |
| 8001/0000 | `imperial fahrenheit` | units |

Watch faces in WearPro come only from the online store (download + file
transfer), so no "switch face" command was captured.

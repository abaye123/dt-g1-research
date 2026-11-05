# DT G1 BLE + Glyphix MAS transport analysis

Interoperability research for the owner's own DT G1 smartwatch (Actions ATS3085S /
the firmware calls it `ats3089`, Glyphix OS). Goal: let a desktop tool talk to the
watch wirelessly, as the WearPro companion app does.

Sources mined (static, local files only, no device, no network):
1. `libglyphix-mas-android.so` (6.1 MB, arm64) extracted from
   `reverse-engineering/wearpro-apk/split_config.arm64_v8a.apk`
   (`lib/arm64-v8a/libglyphix-mas-android.so`). This is the phone side of the MAS
   link. Authored partly in Rust (build paths `/Users/hui/.cargo/...`) and partly in
   C++ (namespace `gx::`), with mbedTLS statically linked.
2. `libmasExtraFeature.so` (3.2 MB) from the same split APK. No extra transport or
   UUID data beyond the main lib.
3. The reference watch firmware `reverse-engineering/ref-firmware-88265/app.bin`
   (ARM Thumb-2, Actions / Zephyr-based `bt_watch` SDK; build path
   `E:/ats3089-glyphix-dtno11111/build/glyphix/...`, "Glyphix Nucleus",
   "Glyphix runtime commit 22f0ca6f"). This is the watch side (the GATT server and
   the MAS peer). Used as data only, never flashed.

The binaries are untrusted data; any instruction-like text in them was ignored.
Confidence is tagged. Byte-exact frame magics and key material are not recoverable
from static strings and are marked UNKNOWN.

---

## 1. BLE GATT service and characteristic UUIDs

RECOVERED (high confidence). The watch firmware is the Actions `bt_watch`
`sppble_stream` transport, which exposes the link over BLE GATT and, in parallel,
over Bluetooth Classic SPP (`bt_manager_spp_reg_uuid`, `sppble_stream`,
`stream_ble_connect_cb`, `stream_spp_connected_cb`). The same byte stream runs over
either carrier; `WRX_CYFIT_BLE`, `WRX_CYFIT_SPP`, `WRX_CYFIT_UART` are the three
carrier variants.

The 128-bit UUIDs are stored as binary in the firmware GATT attribute table (not as
ASCII, which is why `strings` did not find them). They were decoded from the table at
file offset `0x30acf0` in `app.bin` (each entry is a `0x02` type byte = BT 128-bit
UUID, followed by the 16-byte little-endian value):

Primary data service (this is the MAS / Glyphix app-link channel):
- Service       `e49a25f8-f69a-11e8-8eb2-f2801f1b9fd1`
- Characteristic `e49a25e0-f69a-11e8-8eb2-f2801f1b9fd1`
- Characteristic `e49a28e1-f69a-11e8-8eb2-f2801f1b9fd1`

Second service (at offset `0x30bf4d`; secondary / OTA-super channel, appears next to
`AT+WRX=...` debug strings and `ble_super_*` code):
- Service       `f48a23c0-f69a-11e8-8eb2-f2801f1b9fd1`
- Characteristic `f48a24c1-f69a-11e8-8eb2-f2801f1b9fd1`
- Characteristic `f48a25c2-f69a-11e8-8eb2-f2801f1b9fd1`

These `e49a...`/`f48a...-f69a-11e8-8eb2-f2801f1b9fd1` UUIDs are the well-known Actions
Semiconductor sppble family, and the `e49a25...` set was already seen (unexplained) in
the WearPro APK dex (see `wearpro-analysis.md`, section 1). This firmware pins them
down.

Direction of the two characteristics (firmware log string
`[%s] tx_chrc_attr=%p tx_attr=%p tx_ccc_attr=%p rx_attr=%p` proves the layout: one
"tx" characteristic that carries a CCC descriptor = Notify, and one "rx"
characteristic = Write):
- `e49a25e0-...` = TX, Notify (watch -> phone). Subscribe to this for responses and
  pushes. (Listed first after the service declaration, which matches the firmware's
  "tx first" attribute order.)
- `e49a28e1-...` = RX, Write / Write-Without-Response (phone -> watch). Write requests
  here.

Confidence on the two UUIDs: high. Confidence on which of the two is Notify vs Write:
likely as above, but CONFIRM AT RUNTIME by reading the GATT characteristic property
flags (btleplug exposes `NOTIFY` vs `WRITE`/`WRITE_WITHOUT_RESPONSE`); do not hardcode
the direction blindly. The `f48a...` service is probably not needed for normal MAS
traffic.

Note: the firmware also contains test/OTA SPP services using the standard Bluetooth
base UUID with assigned shorts `0xe004` and `0x6666` (near the `spp uuid` /
`spp_test_*` / `ota_app_*` strings at `0x2a6fbb` and `0x2a7dbc`). These are the
factory test and the legacy SD-card OTA channels, not the MAS link.

---

## 2. MAS RPC schema (recovered from symbols and service names)

There is NO protobuf here. Despite the `grpc-java-okhttp` strings in the WearPro dex,
the native MAS layer carries no `.proto`, no `google.protobuf`, and no
`type.googleapis.com` descriptors. (Those gRPC classes are used elsewhere in the app,
likely for phone-to-cloud, not for the device link.) The device link is Glyphix's own
RPC. A protobuf message schema is therefore NOT recoverable, because none exists on
this channel.

What the channel actually is: Glyphix OS is a QuickApp-style JavaScript runtime
("Glyphix Nucleus"). Both the phone and the watch run JS "applets" that reach the
other side through system modules (`require('@system.mas.device')`,
`@system.interconnect`, `@system.rpc`, `@system.filetrans`, `@system.exchange`). The
native layer turns those calls into named RPC/LPC services whose payloads are
serialized as UBJSON.

Serialization = UBJSON (Universal Binary JSON). Evidence (strings, both binaries):
`epush send ubjson message failed, ubjson create failed.`,
`epush ubjson message send result is %d, svc_ret is %d.`. Each service handler has the
C++ signature `mas_rpc_blob* <service>(mas_rpc_blob*)` (demangled example from
firmware: `mas_rpc_blob* gx::os::time_sync_svc(mas_rpc_blob*)`): it takes one request
blob and returns one response blob, each blob being a UBJSON document.

### 2a. LPC / RPC service names (the device-to-device call surface)

These are the registered service names; the request is dispatched by name
(`exec svc`, `lpc svc %s not find`, `not find masRpc service name:`,
`masRpc service (`). Each exists as both `mas_lpc_<name>` and `<name>`:

App / lifecycle management:
- `app_ping_svc`        - presence / keepalive ping (the smallest call)
- `app_list_svc`        - list installed applets
- `app_install_svc`, `app_uninstall_svc`, `app_launch_svc`, `app_exit_svc`
- `we_app_install_svc`  - install a "we" (wearable/applet) package

File transfer and filesystem:
- `push_file_svc`, `we_push_file_svc` - push a file to the watch (dials, maps, OTA,
  music all go through this)
- `pull_file_svc`       - read a file from the watch
- `delete_file_svc`, `lsdir_svc`      - delete / list directory

System:
- `time_sync_svc`                 - time sync (confirmed signature
  `gx::os::time_sync_svc(mas_rpc_blob*)`)
- `notice_link_change_svc`        - link state change notification
- `speed_test_svc`                - throughput test
- `mas_rpc_svc_notification`      - notification push to the watch
- FFI control services: `mas_ffi_svc_update_net_status`,
  `mas_ffi_svc_user_app_exit`, `mas_ffi_svc_discard_test_control`

Native built-in RPC services (phone side, prefixed `mas_rpc_mas_` / `mas_rpc_`):
`mas_http_fetch` / `mas_rpc_udbd_http_request` (the watch tunnels HTTP through the
phone, "Glyphix HTTP Agent"), `mas_fetch_download`, `mas_cover_image` /
`mas_img_cover`, `mas_websocket_connect` / `_send` / `_close`,
`mas_cipher_sign`, `mas_cipher_rsa`, `mas_sign_rsa`, `mas_hmac`,
`start_js_plugin`, `start_web_server`.

### 2b. Typed native services (C++ `gx::` symbols)

Recovered from RTTI / mangled symbols in the `.so`. These are the feature services and
their methods (method = the nested type after the service):
- `BatteryService` -> `Client::GetStatus`           (read watch battery)
- `MessageService` -> `SendMsg`                      (send a message)
- `MasMessageService` (+ `MessageHubModule`)         (message hub)
- `NotificationService`                              (notification mirroring)
- `ExchangeService` -> `Exchange`, with `ExchangeDataWatcher` /
  `ExchangeDataJsWatcher` and `syncExchangeData` / `sync_exchange_data`
  (a shared key/value state block mirrored between phone and watch)
- `InterConnectService` -> `InterConnect(Applet, String, String)`
  ("interconnect install app", "mobile app not support interconnect")
- `FileTransService` -> `PushFile`
- `WebsocketService` / `WebClient` (SimpleWeb `InMessage`/`OutMessage`)
- `CalendarService`, and an `ExeSetCharacteristicNotification` helper
  (this wraps the GATT subscribe described above)

### 2c. Topic / publish-subscribe layer

Above the request/response services there is a topic bus: `subscribe`, `publish`,
`onMessageByTopic`, `fetch.topic`, and on the phone JS side the event subscriptions
`subscribeBLECharacteristicChange`, `subscribeBLEConnectionStateChange`,
`subscribeBLEDeviceFind` (find-my-phone, watch asks phone to ring). Weather, dial
push, notifications and the like are delivered as applet messages over this
bus / the Exchange block, not as fixed-schema RPCs. Their field layout lives in the
applet JS (on the watch's rootfs and in the phone app's JS assets), not in native
code, so exact field names per feature are UNKNOWN from these binaries and are best
captured live (section 5).

---

## 3. Transport framing (how bytes are packed over the characteristic)

Layered, from the GATT write down to the application. Reconstructed from string
evidence; byte-exact header layout and the magic/sign constants are UNKNOWN without a
capture or deeper disassembly.

Layer 1 - GATT / carrier. Phone writes request bytes to the RX characteristic and
receives response/push bytes as Notify on the TX characteristic. The stream is
chunked to the negotiated ATT MTU: firmware `Exchange %s mtu:%d`,
`ATT MTU exceeded, max %u, wanted %zu`, `Invalid mtu %d`, `chunked:`, `Chunk dump:`;
phone side `spp mtu:`, `onMtuChanged(...) mtu=%d`, `maxBufferSize`, `notifySizeMax`.
So: negotiate the largest MTU you can, then split the framed message across
Notify/Write packets.

Layer 2 - MAS link framing (`mas.link.char` for BLE, `mas.link.uart` for USB/UART).
A frame is: a head-sign (start magic) + a header that carries a length +
payload + a CRC16 + a signature field. Evidence:
- `recv frame error, not find frame head sign`  (start magic / sync marker)
- `parse header failed, header length`           (length field in header)
- `link uart frame check crc16 number error.`    (CRC16 over the frame)
- `link char recv need crc length`, `mas.link.frame_check`
- `recv frame error, frame len is right, but eng sign error`  (a per-frame signature
  check that is separate from CRC; see Layer 4)

Layer 3 - MAS D2D (device-to-device) reliable packets. Packets have an id and are
acknowledged; the receiver checks the source. Evidence: `MAS get D2D packet (id:`,
`MAS send D2D packet failed`, `MAS D2D receive data send ACK packet failed.`,
`MAS receive packet source error with id`, `MAS Link Layer port (id:`. This is the
retransmit/ordering layer that sits between the link frames and the RPC.

Layer 4 - crypto (mbedTLS). The "eng sign" check means frames (or the D2D payload)
carry a signature. The lib exposes `mas_hmac`, `mas_sign_rsa` / `mas_cipher_rsa`,
`mas_cipher_sign`, and `cipher remote proto ver` (a version-negotiated cipher).
Firmware: `Error signing data`, `Failed to create ECC public/private pair`,
`generatePairKey` / `generatePairKeySync`. Payload encryption is optional and
negotiated (`mas cipher need decrypt params`). So the link can sign every frame with a
key established at pairing, and may additionally encrypt the payload.

Layer 5 - epush application messaging. `epush` ("exchange push") wraps a service call
as `header + UBJSON body`, with a max message length: `epush message send error
APP_SEND_MSG_LEN_MAX(%d) < header(%d).`, `epush message send total length is`,
`msg_recv_local_control_callback(_epush_recv_data*)`. The UBJSON body is the
`mas_rpc_blob` request/response from section 2.

Layer 6 - RPC dispatch. The epush body names a service; the peer looks it up and runs
`mas_rpc_blob* svc(mas_rpc_blob*)`, returning a UBJSON response blob.

### The authentication gate (critical)

Before the link will accept RPCs, there is a "YZL auth" handshake. Evidence
(firmware): `YZL auth success!` / `YZL auth fail!`, `YZL cmd:0x%04X key:%04X`,
`AT+WRX=setYZLAuth`, `generatePairKey`, plus BLE/BR pairing events
(`MSG_BTSRV_PAIRING_COMPLETE`, `New auth requirements: 0x%x, repairing`). The pair key
produced here is almost certainly the key behind the per-frame "eng sign". A desktop
tool that only opens GATT and writes an unsigned frame will be rejected at the
`eng sign` check. `AT+WRX=setYZLAuth` suggests the auth can also be provisioned over
the watch's USB WRX serial channel, which may be a way to pre-authorize a new client
(worth testing on the USB side, which is already documented in `docs/`).

---

## 4. Rust / btleplug plan to talk to the watch over BLE

Crate: `btleplug` (cross-platform; on Windows it uses WinRT BLE). Steps:

1. Scan and connect. Filter adverts by the service UUID
   `e49a25f8-f69a-11e8-8eb2-f2801f1b9fd1`, or by the watch's advertised name
   (`BT_LE_NAME` / `BT_NAME` in firmware). Connect.
2. Discover services. Find service `e49a25f8-...` and its two characteristics
   `e49a25e0-...` and `e49a28e1-...`. Read each characteristic's `properties`:
   the one with `NOTIFY` is the watch-to-phone channel, the one with
   `WRITE`/`WRITE_WITHOUT_RESPONSE` is the phone-to-watch channel. Do not assume;
   assign from the flags. (Expected: e49a25e0 = Notify, e49a28e1 = Write.)
3. Subscribe to the Notify characteristic (`Peripheral::subscribe`). Start a task that
   reassembles inbound Notify chunks into MAS link frames.
4. Negotiate MTU if the platform allows (WinRT negotiates automatically; the watch
   caps it). Keep your outbound chunk size at or below the negotiated ATT MTU minus 3.
5. Frame a request: build the MAS link frame = head-sign + header(length) + body +
   CRC16 + signature, where body = epush(header + UBJSON{service name, args}),
   wrapped in a D2D packet with an id, then split into MTU-sized Write packets.
   The head-sign magic, the exact header field order, the CRC16 variant, and the
   signature algorithm/key are the UNKNOWNS that a capture (section 5) must fill.
6. Read the reassembled Notify frames, verify/strip CRC and D2D, parse the UBJSON
   response.

Simplest request to try first: `app_ping_svc`. It is a presence ping with a trivial
(likely empty-object) UBJSON request and a small UBJSON response, no file transfer and
no payload schema to get right. It is the cleanest way to prove the full stack
(GATT -> MTU chunking -> link frame -> CRC -> sign -> D2D -> epush -> RPC) end to end.
Close runners-up once ping works: `BatteryService.Client::GetStatus` (read battery,
easy to sanity-check) and `time_sync_svc` (confirmed signature, visible effect on the
watch).

Realistic caveat: steps 5 and 6 cannot be completed from static data alone because of
the unknown frame magic and the YZL-auth-derived signing key. Expect to need one
capture to turn this plan into working bytes.

---

## 5. Fallback: capture live BLE traffic to fill the gaps

The remaining unknowns (frame head-sign magic, exact header/CRC16 layout, the
signature algorithm and whether the pairing key is per-device, the per-feature UBJSON
field names) are all directly observable in a capture. Two options:

Option A - Android HCI snoop log (easiest, no extra hardware). On the paired phone:
enable Developer options -> "Enable Bluetooth HCI snoop log", then pair/connect WearPro
to the DT G1 and exercise one feature at a time (find device, time sync, weather,
battery, push a dial). Pull the log:
`adb bugreport` (the snoop log is inside the zip under `FS/data/...` or
`bugreport.../bluetooth`), or `adb pull /data/misc/bluetooth/logs/btsnoop_hci.log`
where rooted. Open in Wireshark. Filter on ATT writes to handle of `e49a28e1-...` and
notifications from `e49a25e0-...`. This gives you the exact bytes WearPro sends for
each command, including the auth handshake at connection time.

What to capture, in order:
1. The connection + pairing/auth handshake (the `YZL` exchange, `generatePairKey`).
   This reveals whether every frame is signed, the signature size/position, and
   whether a key is exchanged or derived. This is the make-or-break item.
2. An `app_ping` or idle keepalive, to see a minimal complete frame (head-sign +
   header + CRC + sign shape) with almost no payload.
3. Time sync, battery, find-device: small structured RPCs to decode the epush + UBJSON
   layout and confirm service-name encoding.
4. A dial / file push: to decode `push_file_svc` chunking.

Option B - external BLE sniffer (nRF52840 dongle + nRF Sniffer for Bluetooth LE, or a
Sonoff/Ellisys). Follow the connection from the advertising phase (needed so the
sniffer has the channel-hop and, if encrypted at the link layer, the keys). Capture
the same four scenarios. Use this if the phone cannot produce an HCI snoop log.

Decode aids: match captured bytes against the known UBJSON markers (type bytes
`i l d S {` etc.) to find the body, then work outward to find the CRC16 and the fixed
head-sign. The service names from section 2a will appear as UBJSON strings in the body
and are the anchor for alignment.

---

## 6. Feasibility verdict

Hardness of full wireless parity: HARD, but not blocked. The GATT endpoints are now
known, the service surface and the serialization (UBJSON) are known, and the layering
is understood. The two real obstacles are both resolvable with a single HCI snoop
capture:
1. The exact MAS link frame format (head-sign magic, header, CRC16) - static-only
   gives the shape, not the constants.
2. The YZL authentication and the per-frame signing key - this is the gating risk. If
   signing uses a key derived purely from the Bluetooth pairing (LTK/bond), a desktop
   client that performs normal BLE bonding may satisfy it; if it uses a separate OEM
   secret provisioned at first pair, replicating it is harder and may require using the
   `AT+WRX=setYZLAuth` USB path to register the desktop as an authorized peer.

Minimum viable first wireless command: connect to service
`e49a25f8-f69a-11e8-8eb2-f2801f1b9fd1`, subscribe to the Notify characteristic
(`e49a25e0-...`), write to the Write characteristic (`e49a28e1-...`), and issue
`app_ping_svc`. That single round trip proves the entire transport. Everything else
(battery, time, notifications, weather, dial push) reuses the same path and differs
only in the UBJSON body.

Recommended sequence: (1) take one HCI snoop capture of WearPro pairing + ping + time
sync; (2) from it, pin the frame magic, CRC16, and the signing scheme; (3) implement
the btleplug client in section 4 and reproduce `app_ping_svc`; (4) add battery and
time sync; (5) only then move to file push (dials/maps/OTA) via `push_file_svc`. The
already-documented USB `AT+WRX` channel remains the lower-risk parallel path for a
first desktop tool, since it sidesteps BLE pairing and signing entirely.

---

## Appendix: evidence index (where each fact came from)

- GATT UUIDs: `app.bin` binary UUID table at `0x30acf0` (primary) and `0x30bf4d`
  (secondary); decoded as BT 128-bit little-endian entries.
- Characteristic direction: `app.bin` string
  `[%s] tx_chrc_attr=%p tx_attr=%p tx_ccc_attr=%p rx_attr=%p`.
- Transport = Actions sppble_stream over BLE + Classic SPP: `app.bin` `sppble_init`,
  `bt_manager_spp_reg_uuid`, `stream_ble_connect_cb`, `WRX_CYFIT_BLE/SPP/UART`.
- No protobuf: absence of `.proto` / `google.protobuf` / `type.googleapis.com` in
  `libglyphix-mas-android.so` and `app.bin`.
- UBJSON: `epush send ubjson message failed`, `epush ubjson message send result`.
- Service names: `libglyphix-mas-android.so` and `app.bin` strings (`*_svc`,
  `mas_lpc_*`, `mas_rpc_*`); demangled `gx::os::time_sync_svc(mas_rpc_blob*)`.
- Typed services: C++ RTTI symbols in `libglyphix-mas-android.so` (`gx::BatteryService`,
  `gx::FileTransService::PushFile`, `gx::InterConnectService`, `gx::ExchangeService`,
  `gx::NotificationService`, `gx::MessageService::SendMsg`).
- Framing layers: `mas.link.char`, `mas.link.frame_check`, `recv frame error, not
  find frame head sign`, `link uart frame check crc16 number error`, `MAS get D2D
  packet (id:`, and the MTU/chunk strings listed in section 3.
- Crypto / auth: mbedTLS strings; `mas_hmac`, `mas_sign_rsa`, `cipher remote proto
  ver`; firmware `YZL auth success!`, `generatePairKey`, `AT+WRX=setYZLAuth`,
  `Error signing data`, `Failed to create ECC public/private pair`.

> Source: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). This is an unofficial translation.

# findings_R19 - ✅✅✅ Sideload success: com.rtos.qrwatch installed and running on the OWW262 (2026-10-11 10:15-10:24)

> Window 19. The transport chain built in the previous 18 windows + this window's format fix = complete delivery.

## Final result (evidenced by the assistant log)
```
10:15:51.842  安装应用 成功  {"code":200,"msg":"success"}   ← v1 (3136B, with icon)
10:16:45.985  启动应用 成功                                   ← com.rtos.qrwatch
10:23:24.491  安装应用 成功  (total_size:3488)                ← v2 (10-second auto carousel)
10:24:02.366  启动应用 成功
```
The user visually confirmed: **the QR code screen appeared on the watch** (the desktop entry shows the Wooden Fish icon slot, see the known issues below).
Watch-side RPC log corroboration: `mas.ffi: exec ffi fun app_launch` + `lvgl: eventLoop refresh startup` (UI event loop started, no errors at all).

## Root cause of 5005 "invalid package" (the core finding of this window)
- It was **not** a channel problem, not a signature problem, not a file name problem (changing the suffix to .rpk had no effect)
- **Root cause = the package lacked an app icon**:
  - Official docs (github.com/glyphix-os/web-docs -> framework/application/manifest.md)
    the Manifest type signature `icon: string` is **required** ("path of the app icon, e.g. /assets/icon.png")
  - Old package: no icon file, no icon field in the manifest -> the watch runtime (nucleus) reports invalid package or manifest
  - Fix: src/assets/icon.png + manifest `"icon": "/assets/icon.png"` + rebuild the package with gx build -> passed first time
- Minor correction: in the custom device config oppo-rtos-watch.yml, vendorID/productID were changed from 0x1234/0x5678 back to 0x0000/0x0000 (the generic-family convention, to avoid device validation risk)

## The correct sideloading procedure (later windows can copy it directly)
1. The project's src/manifest.json must contain: package/name/**icon**/versionName/versionCode/router
2. `gx build -d oppo-rtos-watch` (use -f for a full build; an incremental build does not re-burn the device ID)
3. The artifact `.glyphix-work/dist/oppo-rtos-watch/<pkg>/bundle.pkg` is installable as is
   (official docs: the dist triple is bundle.pkg+icon.png+manifest.json, "install to the device through the phone debug app")
4. Guiyuan Assistant -> Install app -> choose the package file -> success; Launch app -> com.rtos.qrwatch
5. Upgrade: just reinstall (pkg.install semantics, a running app is exited first and then upgraded); versionCode+1

## Known issues (non-blocking)
- **The desktop icon shows as Wooden Fish**: the OWS desktop does not read third-party package names and the icon slot is shared (a known bug in the bandbbs thread 29508);
  after installing a third-party app you need to **restart the watch** for it to appear on the desktop correctly. The full fix = install Purrlaunch (disguised as com.xfaith.woodenfish,
  you must uninstall Wooden Fish first) - the rpk is in the bandbbs thread attachment 10856.webp, the forum account is awaiting admin approval and needs replying to the thread, so it is unobtainable for now.
- The assistant's "Launch app" command succeeds but may not bring the app to the front (opening it from the desktop works normally).
- The "check install" interface has unreliable semantics (it once returned true for an uninstalled package) and cannot be used as the install criterion; rely on the install / launch return codes.

## Environment wrap-up
- ✅ authentication_state set back to 0 (done around 10:38, 1->0)
- ✅ The unattended auto_verify loop is stopped (log ends at 07:47 round=30)
- Toolchain: G:/oppo/.toolchain (gx v0.11.0); official docs clone: work/glyphix_os/web-docs
- App source: G:/oppo/com.rtos.qrwatch/src (v2: 10-second auto carousel + tap to switch manually, qr-data.js holds the code content)

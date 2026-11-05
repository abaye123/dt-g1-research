> Source: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). This is an unofficial translation.

# Complete Guide to Glyphix App Development and Sideloading
### Target platform: OPPO Watch S (OWW262) · Glyphix OS · 466×466 round screen
> 2026-10-11 · Based on measured conclusions from windows 10~20 · Companion: `docs/findings/` (protocol reverse-engineering archive), `docs/SOURCES.md` (provenance and attribution of external resources)
> Every conclusion marked ✅ has been verified on a real device; ⚠️ marks a pitfall we stepped in.

---

## 0. Just want to get an app onto the watch

```bash
npm install -g glyphix-cli             # once
python tools/ows.py install qrwatch    # every time: build + push to the phone
```

When it finishes, just tap "安装应用" (Install app) on the phone. If stuck, first run `python tools/ows.py doctor` (checks the environment item by item and gives a fix for whatever is missing).

> **If you are in a hurry, read only §0 + §6 (troubleshooting).**
> §1~§4 are the principles and the manual flow; **§5.3 (desktop icon) and §8 (store protocol reverse engineering) are advanced, the app works fine without them**.

---

## 1. Platform architecture: who does what

```
┌─────────────┐  adb drive/push files  ┌──────────────┐                  ┌──────────────┐
│ PC (this repo) │ ──────────────→ │ Phone PJD110   │ ── BT/PTC protocol──→ │ Watch OWW262  │
│ gx toolchain    │                 │ com.heytap.  │   (official channel)       │ Glyphix      │
│ Python tools    │                 │ health       │                  │ nucleus 0.7  │
└─────────────┘                 │ com.glyphix. │── debug channel (whitelist)─→│ runtime 0.7  │
                                │ assistant    │   ★ sideloading uses this    └──────────────┘
                                │ (Guiyuan Assistant)    │
                                └──────────────┘
```

- **Glyphix OS**: OPPO's lightweight JS app system (quick-app style: UX templates + @system.* APIs). The open-source docs are at github.com/glyphix-os/web-docs (**check them before writing code**; cloning a copy locally is recommended).
- **There are two install channels**:
  - **Debug channel** (Guiyuan Assistant "Install app") → ✅ the standard route of this guide. It does not verify signatures and does no strong validation of package contents (it only requires a valid manifest + all required fields present).
  - **Store channel** (Health app / direct PTC protocol push) → windows R10~R18 reverse engineered the transport layer completely (file delivery verified at MD5 level 8+ times), but the watch side never lets self-made packages through its install validation (cid=5 is "staging", not InstallDone). **Consider it only when you do not have Guiyuan Assistant; the archive is in section 8.**

---

## 2. Environment checklist and notes

### 2.1 PC
| Item | Location/value |
|---|---|
| gx toolchain | `npm i -g glyphix-cli` (npm latest is 0.8.0-rc, the installed `gx` version is **v0.11.0**); use `where gx` to find the actual location |
| Device config | `%APPDATA%\glyphix\devices\oppo-rtos-watch.yml` - just copy this repo's `devices/oppo-rtos-watch.yml` there (vendorID/productID are fixed to 0x0000/0x0000, do not change back to the probe values 0x1234/0x5678) |
| Package format tool | This repo's `tools/pkg_tool.py` (info/list/manifest/extract/pack/setdevice; for the CR container format see PKG_FORMAT.md) |
| Official docs | Online at github.com/glyphix-os/web-docs (can be cloned to any directory; api/ components/ framework/ tutorials/) |
| Python | 3.x + Pillow (used to generate icons) |

**Device config installation (required the first time)**: this repo's `devices/oppo-rtos-watch.yml` must be copied to gx's data directory:
```bash
gx list path        # shows the data= line, i.e. <data-dir>
cp devices/oppo-rtos-watch.yml <data-dir>/devices/
gx list device      # oppo-rtos-watch appearing means success
```

⚠️ Git Bash converts `/sdcard/...` into a local path: **run `export MSYS_NO_PATHCONV=1` before every adb file operation**.

### 2.2 Phone (adb device <adb-serial>, PJD110)
| Package | Purpose |
|---|---|
| com.glyphix.assistant | **Guiyuan Assistant v1.2**: the sideload installer (upstream has released v1.3, unverified; see §10 for the release page). Six UI buttons: Connect / Device info / Check install / Install app / Launch app / Device log |
| com.heytap.health | OPPO Health: bridge host + watch app store |

### 2.3 Watch (OWW262)
- vendorId=17170433(0x01060001), nucleus 0.7.0-44 / runtime 0.7.0-68, round screen 466×466
- **Connection requirement**: wear the watch / raise your wrist to keep it active; deep sleep disconnects it and the PC cannot wake it
- **RPC log** (Guiyuan Assistant "Device log") = the watch-side real-time log stream, the first place to look when troubleshooting (see section 6)

---

## 3. App project conventions

### 3.1 Directory structure
```
<project>/
├─ src/
│  ├─ app.js               # app lifecycle
│  ├─ manifest.json        # app manifest (icon is required! see 3.2)
│  ├─ assets/icon.png      # icon (192×192 PNG measured to pass)
│  └─ main/
│     ├─ index.ux          # page = <template> + <style> + <script>
│     └─ <data>.js         # data module used by the page (ES import)
```
Reference projects: `apps/qrwatch/src/` (QR code app, the minimal working project) and `apps/purrlaunch-ows/` (OWS adaptation delta of PurrLaunch).

### 3.2 All manifest.json fields (★=required)
```json
{
  "package":    "com.example.app",
  "name":       "应用名",
  "icon":       "/assets/icon.png",
  "versionName":"1.0.0",
  "versionCode": 1,
  "features":   [],
  "router": {
    "entry": "main",
    "pages": { "main": { "component": "index" } }
  },
  "config":  { "designWidth": 466 },
  "permissions": [ { "name": "watch.permission.XXX" } ],
  "display": {}, "dial": {}, "widgets": []
}
```
- `package` ★ globally unique, com.xxx.yyy recommended; avoid `-` `_` `.`
- `name` ★ at most 6 Chinese characters, used for display on the desktop
- `icon` ★ **required! if missing → 5005 invalid package on the watch (the biggest pitfall of this project, see section 5)**
- `versionCode` ★ an integer, +1 on each release (the basis for upgrade decisions)
- `router` ★ page routing; `config.designWidth` is 466 for OWS
- ⚠️ The official template runs in the emulator without icon, but **a real-device install must add it**

### 3.3 Quick overview of the index.ux page file
- Template directives: `for="{{(idx, item) in items}}"`, `if="{{cond}}"`, event `on:click="fn"`, attribute binding `:value="{{expr}}"`, interpolation `{{expr}}`
- Styles: a CSS subset; it is recommended to set `width:466px; height:466px` explicitly on the page root
- Component list (web-docs components/): div/p/stack/scroll/button/image/canvas/**qrcode**/barcode/input/slider/progress/marquee/picker… (qrcode supports up to QR v12 ≈ 300 bytes of payload)
- **Page lifecycle** (order measured in the real-device RPC log): `onInit → onReady → onShow → (onHide → onShow…) → onDestroy`
- **App lifecycle** (app.js): `onCreate/onShow/onHide/onDestroy/onError/onPageNotFound`
- Timers: global `setInterval/clearInterval` (remember to clear them in onHide on the page)

### 3.4 Common APIs (`import pkg from '@system.package'` style)
| Module | Usage verified in this project |
|---|---|
| @system.package | `list('app')→array of package names`, `getInfo(pkg)→{name,versionName,icon…}`, `install({src})`, `remove` |
| @system.launch | `launch(pkg)→Promise<bool>` launch and bring to front, `getRunning()`, `exit()` |
| @system.file | readText/writeText/list/copy/mkdir/stat… (for later use in a file browser / icon cache investigation) |
| @system.devtools | `command(cmd, fn)` registers a `dev` terminal command |
| Others | ble/geolocation/media/notification/schedule/battery/cipher/fetch/i18n… see web-docs api/ |

---

## 4. Build and install SOP (✅ the whole flow is copyable)
> One-line script: `python tools/ows.py install <app>` (= build + push + trigger media scan). Below is the manual flow.

### 4.1 Build
```bash
cd <project>
../.toolchain/node_modules/@glyphix/cli-win32-x64/bin/gx.exe build -d oppo-rtos-watch -f
```
- `-d` target device; **`-f` full build** (⚠️ an incremental build does not re-burn the manifest device ID - after changing the device config you must use -f)
- Artifacts: `.glyphix-work/dist/oppo-rtos-watch/<package>/` → **bundle.pkg (this is the install package)** + icon.png + manifest.json (the store submission triple; sideloading only needs bundle.pkg)
- Image conversion depends on pngquant (needed by generic-* configs; measured not needed by the oppo-rtos-watch config)

### 4.2 Install (Guiyuan Assistant)
```bash
export MSYS_NO_PATHCONV=1
adb push <project>/.glyphix-work/dist/oppo-rtos-watch/<pkg>/bundle.pkg /sdcard/Download/xxx.rpk
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Download/xxx.rpk
```
Then: Guiyuan Assistant → Install app → Files tab → Download → choose the package → the log shows `安装应用 成功 {"code":200}`.
- Any file name works (the content decides everything); after success you can "Launch app" right away (enter the package name, 200 = launched)
- **Upgrade**: just reinstall, versionCode must be larger than the installed one
- **Overwriting a store app**: ✅ measured to work (purrlaunch-lite overwrote the store version of Wooden Fish, the debug channel does not block on signatures)

### 4.3 Acceptance criteria
- Install criterion = **the install / launch return code** (the "check install" interface has unreliable semantics, do not use it)
- Run criterion = the RPC log shows `app.life: call onInit/onReady in pkg://<package name>/main/index.uo` + `eventLoop refresh`

---

## 5. Icons and the desktop mechanism (✅ solved: the `icon_<package name>` registration method)

### 5.1 Icon resources
- **com.rtos.qrwatch (QR code app)**: white background + black QR code pattern, 192×192 PNG (843B)
- **purrlaunch / PurrLaunch (launcher, package name com.xfaith.woodenfish)**: cat paw pattern (official version) / four-color grid (lite version)
- The icons are all inside the package (`assets/icon.png` + the manifest `icon` field) - visible at runtime; **the desktop display goes through a separate registration mechanism (see 5.3)**

### 5.2 Root cause of the gear phenomenon (full causal chain, proven)
1. The OWS desktop shows a gear (an Android-settings-like icon) for sideloaded apps = the icon registry lacks an icon entry for that package → fallback rendering
2. The icon registry is **data-driven**: when the store installs an app, the Health app **transfers an icon file separately** outside the package file and registers it
   (real-device store log 08:26: ~120ms after the `pkg_com.xfaith.woodenfish` transfer completed, `icon_com.xfaith.woodenfish` was sent, an 11294B PNG)
3. The Guiyuan Assistant debug channel only sends bundle.pkg → no icon in the registry → gear
4. Neither the icon bundled in the package nor the icon declared in the manifest **can** make the desktop display it - the desktop only recognizes the registry
5. The PurrLaunch author's (DT NO.1 G1) desktop is a "hardcoded menu + OS-baked icons", not isomorphic with OWS; the OWS mechanism can be fixed from the package side / file side

### 5.3 ★ Standard SOP: registering/replacing a desktop icon for a sideloaded app (✅ verified, **advanced item**)
> Not doing it does not affect install or running; the desktop just shows a gear. It requires building a probe with the Android SDK, the most troublesome step in the whole repo.
> Verification records: R21b (com.rtos.qrwatch, the user visually confirmed the desktop icon became a QR code pattern) + R21c (two icons registered in the same batch, wire complete)

**Prerequisites**
- The probe `tools/ftprobe` (built at R21c or later) is installed on the phone; the watch has reconnected (online)
- The phone is **screen on + unlocked** (Android 14 force-kills the probe Activity when locked / not visible: `did not call finish`)

**Steps**
1. Put the icon PNG in `tools/ftprobe/assets/`, with the working name = `icon_<target package name>` (no extension; 192×192 843B measured to work)
2. In `src/com/rtos/ftprobe/MainService.java` → at the end of `fireOp4AndUnlock()`, add the pair
   `{asset name, "icon_<target package name>"}` to the `icons[][]` array
3. `python build_probe.py` → `adb install -r build/FtProbe18.apk`
4. `adb shell settings put secure authentication_state 1` (required for the probe to impersonate the Health agent and pass framework authentication; **you must set it back to 0 when done**)
5. Screen on and unlocked → `adb shell am start -n com.rtos.ftprobe/.MainActivity` → keepalive: repeat WAKEUP+am start every 15s,
   for about 3 minutes in total (prevents ColorOS virtualFreeze; the probe automatically completes the whole chain cid=10 → pkg×3 → icon_<package name> → cid=3)
6. Wire verification: `adb logcat` capturing `[sfcmd]FT_SETUP_REQ sent,...fileName:icon_<package name>` +
   `handleTransferComplete: Completed :icon_<package name>`
7. **Restart the watch** → the desktop icon takes effect ✅

**Principle**: the watch-side icon registry routes by file name - `icon_<package name>` + `FileInfo=appstore_uri_icon` delivered through the
`wear:watchappservice_file:1.0` (sid=272) channel is registered on arrival; same channel as the package file (`pkg_<package name>`+`appstore_uri_package`)
but a different routing key. For an **already installed** app you can just send it afterwards, with no need to reinstall the app; it persists after restart.

### 5.4 Limits and leftovers
- This method depends on the probe (authentication bypass); Guiyuan Assistant v1.2's install does not include icon registration (v1.3 unknown - if v1.3 automatically carries icon.png it would be simpler)
- The icon content can be any PNG (192×192/843B up to 432×432/1.7KB all work); the original store image is 11294B (size-insensitive)
- The desktop menu entries themselves are still hardcoded (a third-party app that must "appear on the desktop" still needs to take over the Wooden Fish slot - solved by PurrLaunch);
  icon registration solves "which image is shown"

---

## 6. Debugging and troubleshooting

### 6.1 Reading Guiyuan Assistant log lines
| Log | Meaning |
|---|---|
| `连接服务: com.heytap.health → 连接成功` | Bridge ready |
| `安装应用 进度 {cur_size,total_size}` | Package transfer in progress |
| `安装应用 成功 {"code":200}` | Installed |
| `安装应用 失败 {"code":5005,"msg":"invalid package"}` | Invalid manifest (nine times out of ten missing icon) or broken container |
| `启动应用 成功/失败 {"code":5001,"msg":"The package was not found"}` | Package name does not exist (not installed / misspelled) |
| `切换 rpc 日志 成功` | Watch log stream switched on/off |

### 6.2 Key lines in the watch-side RPC log
| Line | Meaning |
|---|---|
| `mas.ffi: exec ffi fun app_launch` | The launch command reached the watch |
| `app.life: call onShow in pkg://<package name>` | App-level onShow |
| `app.life: call onInit/onReady in pkg://<package name>/main/index.uo` | Page init / ready |
| `lvgl: exit application <package name> success` | The app was exited (upgrade overwrite / exit) |
| `lvgl: eventLoop refresh N … stop it` | Render loop normal (refresh stops after 5 frames once static) |
| `gx_on_screen_on/off` | Watch screen on/off (not seeing anything when launching with the screen off is normal) |
| `query network status / mas network … online` | Watch network status |

### 6.3 Error code quick reference
| Code | Source | Meaning |
|---|---|---|
| 200 | Assistant operations | Success |
| 5001 | Launch app | Package does not exist |
| 5005 | Install app | Invalid package (missing icon / broken container) |
| 10002 | R17 protocol chain | urn lacks a version number → profileId parsing error |
| 10110 | R17 protocol chain | sendMessage frame buffer insufficient (specific to the protocol chain) |

### 6.4 Ten-pitfall quick list
icon required / the store channel cannot install self-made packages / desktop gear icon / watch deep sleep disconnects / ColorOS freezes the probe / emulator lacks a launcher / CDN needs signatures / UI automation popups cutting in + screen rotation / MSYS_NO_PATHCONV / small logcat buffer.

For the first four, the remedies are in §3.2 (icon), §1 (channel), §5 (icon), §2.3 (deep sleep disconnect) respectively; the rest are environment pitfalls from the reverse-engineering phase that you will not meet in day-to-day development.

---

## 7. Launcher: the OWS adaptation of PurrLaunch (already running on the watch)
- Location in this repo: `apps/purrlaunch-ows/` (the minimal adaptation delta of upstream purrrock/PurrLaunch v1.2.2, MIT, see OWS-ADAPTATION.md in that directory)
- Package name `com.xfaith.woodenfish` (takes over the original Wooden Fish)
- Note: earlier there was also a self-built purrlaunch-lite (versionCode 8), later overwritten by the official PurrLaunch, **not published with the repo**
- Function: `pkg.list('app')` dynamic list (system packages last, itself hidden) → tap to `launch()`
- Verified: overwriting the store version of Wooden Fish ✅; page lifecycle/rendering fully working ✅; newly installed apps appear in the list automatically
- To go back to Wooden Fish: reinstall from the watch app store (that in turn overwrites the launcher); to change the launcher: edit src and reinstall per section 4

---

## 8. Deep-water archive index (store protocol reverse engineering - only needed to "bypass Guiyuan Assistant")
| File | Content |
|---|---|
| docs/findings/findings_R14_transfer_success.md | End-to-end file delivery + the five fixes that must all be right at the same time |
| docs/findings/findings_R15_cid10_protocol.md | Reconstruction of the cid=10 install precheck protobuf protocol |
| docs/findings/findings_R16_cid10_live.md | cid=10 live fire |
| docs/findings/findings_R17_wireformat.md | MEX frame contract (15B header, offset=15, the only viable main path) |
| docs/findings/findings_R18_final.md | 1:1 replication of the complete install chain + authoritative table of MsgBody field numbers |
| docs/findings/findings_R19_sideload_success.md | Root cause of 5005 + the whole successful debug-channel process |
| docs/findings/findings_R20_launcher.md | Self-built launcher + upgrade-overwriting a store app |
| tools/ftprobe/ (versionCode 18) | Protocol probe: cid=10 + Op4 file push + cid=3 list, rerunnable in one click |
| (not published with the repo) auto_verify.sh | Unattended verification loop (stopped, kept for reference) |

When needed: when you want to silently install / mass-distribute apps **without any phone UI interaction**, or study the store download protocol. Day-to-day development **does not need** it.

---

## 9. Directory mapping: repo ↔ original working directory

This repo is a **public subset** of the original working directory: reproducible tools, source and docs are all in the repo;
parts involving vendor decompiled output keep only the conclusions and the raw files are not published (see the disclaimer at the end).

| Repo path | Content | Counterpart in the original working directory |
|---|---|---|
| `README.md` | Three-step quick start (the manual flow is folded in details) | - |
| `docs/DEV_GUIDE.md` | This document | `DEV_GUIDE.md` |
| `docs/PKG_FORMAT.md` | CR container format specification | `pkg_tools/PKG_FORMAT.md` |
| `docs/findings/findings_R14~R21*.md` | Per-window battle reports (store protocol reverse engineering) | `work/findings_R1x*.md` |
| `docs/findings/findings_master.md` | Full summary | summary in `work/` |
| `docs/SOURCES.md` | Provenance / attribution / verification dates of external resources | new |
| `apps/qrwatch/` | QR code app (v2: 10-second auto carousel) | `com.rtos.qrwatch/` |
| `apps/library-qr/` | Library reader card dynamic code (ecosystem example) | - |
| `apps/purrlaunch-ows/` | OWS adaptation delta of PurrLaunch | `PurrLaunch/` |
| `tools/guiyuan-assistant/` | Guiyuan Assistant APK mirror + notes | `work/glyphix_assistant/` |
| `tools/ftprobe/` | Protocol probe (including desktop icon registration) | `work/ftprobe*/` |
| `tools/ows.py` | One-stop script (doctor/setup/build/push/install) | new |
| `tools/pkg_tool.py` | Package format reader/writer | `pkg_tools/pkg_tool.py` |
| `devices/oppo-rtos-watch.yml` | gx device config | `%APPDATA%\glyphix\devices\` |

**Local only, not published with the repo**: `HANDOFF.md` (handover note), `purrlaunch-lite/` (superseded by the official PurrLaunch),
`com.rtos.pkg` (old store-format package, missing icon gives 5005, do not use it for installing again), `.toolchain/` (gx install directory),
`work/oafsrc/` and `work/routesrc/` (Health app decompiled fragments), `work/store_catalog.json` (store metadata), `work/auto_verify.sh`.
Decompiled output is not published per the disclaimer; only the behavioral conclusions in `docs/findings/` are kept.

> The battle reports under `docs/findings/` are the original working logs of the time; the `G:/oppo/...` and `work/...` that appear in their text are **local paths of the time**,
> see the table above for the mapping; to preserve the original record they were not rewritten, so convert them using the table when reading.

## 10. Reference links

- **Official Glyphix docs**: [github.com/glyphix-os/web-docs](https://github.com/glyphix-os/web-docs) (check it before writing code; clone it locally to any directory)
- **Mitan tutorial**: [bandbbs.cn/threads/29508](https://www.bandbbs.cn/threads/29508/) - author libiao0418, **only the tutorial author**.
  On 2026-10-10 the thread added a cloud drive link for the tools used in the tutorial (password in the original thread); if you need attachments such as the Purrlaunch rpk, get them as the original thread instructs.
- **Guiyuan Assistant original release page**: [pgyer.com/glyphix-assistant](https://www.pgyer.com/glyphix-assistant) - distributed via Pgyer, package name `com.glyphix.assistant`;
  the page **does not state an author**, do not fill in a name (verification record in `docs/SOURCES.md`).
- **PurrLaunch**: upstream [github.com/purrrock/PurrLaunch](https://github.com/purrrock/PurrLaunch) (MIT, v1.2.2), with no attribution relationship to the tutorial author above.
- **glyphix-cli**: npm package, currently latest = 0.8.0-rc, the installed `gx` is v0.11.0.

> The complete provenance of external resources, verification dates and "which fields can be checked / which cannot be found" are all recorded in `docs/SOURCES.md`.

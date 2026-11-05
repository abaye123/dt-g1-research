> Source: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). This is an unofficial translation.

# Guiyuan Assistant (Glyphix Assistant) v1.2

Phone-side sideload installer - **the core tool of this repo's standard flow**. It bridges to the watch through OPPO Health (com.heytap.health)
and provides debug-channel capabilities such as "Install app / Launch app / Check install / Device log".

- **Original release page**: [pgyer.com/glyphix-assistant](https://www.pgyer.com/glyphix-assistant) - a Pgyer app distribution page, package name `com.glyphix.assistant`.
- **Attribution**: the release page above **does not state an author / developer**, and this repo cannot verify one either, so no name is filled in. Copyright belongs to the tool's author; the release page prevails.
- **Upstream version**: the release page is currently at **v1.3 (build 3, 2026-10-08)**, release note "supports OHealth"; this repo mirrors **v1.2 (build 2, 2026-08-21)**.
  The in-app "new version 1.3 found" popup uses the Pgyer update check API (the APK contains a call to `pgyer.com/apiv2/app/check`).
- **Mirror source**: the attachment of the Mitan community tutorial thread [bandbbs.cn/threads/29508](https://www.bandbbs.cn/threads/29508/) (forum account required).
  The author of that thread, libiao0418, is the **tutorial author**, not the author of this tool, merely a user of it.
- **Lineage**: per the tutorial text, since 2.5.0 the Glyphix OS debug tool `glyphixdebug` split its "bridge mode" out into Guiyuan Assistant.
  The APK uses classes of the `com.glyphix.interconnect` family (`GlyphixInterconnect` / `GlyphixDebug` / `GlyphixWear263`),
  i.e. it is built on Glyphix's interconnect SDK - this only says which SDK is used and is not evidence of authorship.

> How the release page was determined, the version comparison, and "which fields can be checked / which cannot be found" are in [`docs/SOURCES.md` §1](../../docs/SOURCES.md).

- **Search record (2026-10-21)**: GitHub searches for "瑰元助手", "com.glyphix.assistant", "glyphix assistant" all returned **no related repo or source**;
  the tool has no GitHub release channel, and the Pgyer page is its distribution entry.
- **Correction record**: on 2026-10-21, per issue #1 - the **tutorial author** had been mistaken for the tool's author, and a baseless third-party account had been attached;
  all such statements have been deleted. Only fields that can be checked on the release page on the spot are kept (package name, version, update time).
- **Version**: mirrored v1.2 (versionCode 3 as measured by this repo; build 2 on the Pgyer side); upstream is already at v1.3 (build 3)
- **Package name**: com.glyphix.assistant · main Activity: `com.xfaith.interconnect.MainActivity`
- **SHA256**: `5d7389524a494291251effb07fda67e06bbf43a89fa209b6824dd1d849661b27`
- **Copyright**: belongs to its author. This mirror is distributed only to reproduce the research flow; if the author asks for removal, contact the repo maintainer.

## Usage flow

1. Install this APK on the **phone** (not the watch - it is not a watch app)
2. Power on the watch and connect it to the phone over Bluetooth (OPPO watches come bound to OPPO Health / quick-connect services out of the box)
3. Open Guiyuan Assistant:
   - **Connect** (连接): queries 1 service -> `连接服务: com.heytap.health` -> `连接成功` (connected)
   - **Device info** (设备信息): should return `{"brand":"OPPO","model":"OWW262",...}` (the identity of the OWS)
4. **Install app** (安装应用): choose a `.pkg`/`.rpk` package in the file picker -> when the log shows
   `安装应用 成功 {"code":200,"msg":"success"}` it is installed
5. **Launch app** (启动应用): enter the package name -> 200 means launched (note: it may not come to the front; launching from PurrLaunch / the desktop is more intuitive)
6. **Device log** (设备日志): the watch-side real-time RPC log stream (a great debugging aid, see the repo's DEV_GUIDE §6.2)

## The six buttons

| Button | Function | Notes |
|---|---|---|
| 连接 (Connect) | Binds the Health app bridge service | Must reconnect after each reopen |
| 设备信息 (Device info) | Reads the watch identity (model/version/VID) | Verifies the bridge |
| 检查安装 (Check install) | Returns 200 + true/false | ⚠️ Unreliable semantics, do not use as the install criterion |
| 安装应用 (Install app) | SAF file pick -> push the package and install | Any file name, the content decides everything |
| 启动应用 (Launch app) | Launch by package name | 5001 = package does not exist |
| 设备日志 (Device log) | Watch-side RPC log stream | `app.life` / `lvgl` / `mas.ffi` entries |

## Known behavior (measured on v1.2)

- The "new version 1.3 found" popup keeps coming back, just dismiss it
- Install does **not** register a desktop icon (the gear problem) - requires pushing `icon_<package name>`, see the repo's DEV_GUIDE §5.3
- Does not verify signatures, can upgrade-overwrite store apps (versionCode must be no lower than the installed version)

> Source: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). This is an unofficial translation.

# OPPO Watch S Sideload Toolchain (Glyphix OS)

Install your own JavaScript apps on the **OPPO Watch S (OWW262, Glyphix OS, not Android)**.
The whole flow has been verified on a real OWW262 (nucleus 0.7.0-44 / runtime 0.7.0-68).

**Just want to get an app onto the watch? The three steps below are enough; you can ignore the other directories for now.**

You need: an OPPO Watch S + an Android phone (with OPPO Health installed, connected to the PC by cable with "USB debugging" on) + a PC (Node.js, Python 3).

## Three steps to install

```bash
# 1) PC, once: install the build toolchain
npm install -g glyphix-cli

# 2) Phone, once: install Guiyuan Assistant (use the copy in this repo, or download the latest from the release page)
#    tools/guiyuan-assistant/glyphix-assistant-v1.2.apk
#    https://www.pgyer.com/glyphix-assistant

# 3) PC, every time: build + push to the phone, in one step
python tools/ows.py install qrwatch
```

When step 3 finishes it prints the two taps you need to make on the phone:

1. Open "瑰元助手" (Guiyuan Assistant) -> tap "连接" (Connect) -> the log shows `连接成功` (connected)
2. Tap "安装应用" (Install app) -> Files -> Download -> choose `qrwatch.rpk`

When the log shows `安装应用 成功 {"code":200}` (install succeeded), it is installed. To launch it, tap "启动应用" (Launch app) and enter the package name.

**If you get stuck, run `python tools/ows.py doctor`.** It checks Node / gx / device config / adb / phone connection one by one,
and gives the fix command for whatever is missing - no need to guess which step is the problem.

> The purpose of `tools/ows.py` is to seal off four pitfalls you will certainly hit:
> no device config in gx, Git Bash converting `/sdcard/...` into a local path, no media scan after push
> (the package is invisible in the assistant's "Download" list), and not remembering the build output path.

<details>
<summary>Don't want to use the script? Doing it by hand is just three commands</summary>

```bash
export MSYS_NO_PATHCONV=1          # required in Git Bash
cd apps/qrwatch && gx build -d oppo-rtos-watch -f
adb push .glyphix-work/dist/oppo-rtos-watch/*/bundle.pkg /sdcard/Download/qrwatch.rpk
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///sdcard/Download/qrwatch.rpk
```

If you don't have the `oppo-rtos-watch` device config, copy `devices/oppo-rtos-watch.yml` to
`%APPDATA%\glyphix\devices\` (or just use `python tools/ows.py setup`).

</details>

## Writing your own app

To change the QR code content: edit `apps/qrwatch/src/main/qr-data.js`.
For a new project: copy `apps/qrwatch/` and change `package` / `name` in the manifest.

```json
{
  "package": "com.yourname.app",
  "name": "你的应用",
  "icon": "/assets/icon.png",
  "versionName": "1.0.0",
  "versionCode": 1,
  "router": { "entry": "main", "pages": { "main": { "component": "index" } } }
}
```

⚠️ `icon` is **required for installing on a real OWS device**; without it you get 5005 `invalid package` (the official template runs in the emulator without it, don't be fooled).
For page syntax, components and the `@system.*` API see the [official docs](https://github.com/glyphix-os/web-docs) and
[docs/DEV_GUIDE.md](docs/DEV_GUIDE.md) §3. To upgrade, just reinstall; `versionCode` must be larger than the installed one.

## Advanced (the app works fine without these)

Read on only if you want these after the app is installed. **If you do none of them, the app can still be installed, run, and launched from the assistant.**

| What you want | How | Cost |
|---|---|---|
| A launcher icon entry on the watch face menu (none by default, the menu is hardcoded) | Install PurrLaunch to take over the "Wooden Fish" slot | Install one package, 5 minutes |
| A desktop icon that is not a gear | Use `tools/ftprobe/` to push `icon_<package name>` and restart the watch | Needs the Android SDK to build the probe, the most troublesome step |
| Silent install without touching the phone UI / research the store protocol | Read the reverse-engineering archive in `docs/findings/` | Reading only |

For the full desktop and icon mechanism see [DEV_GUIDE §5](docs/DEV_GUIDE.md); the protocol archive index is in §8.

## Directory layout

```
tools/ows.py          one-stop script (doctor / setup / build / push / install)
docs/DEV_GUIDE.md     ★ full development guide (platform architecture, manifest, build and install, icon mechanism, troubleshooting)
docs/SOURCES.md       provenance / attribution / verification dates of external resources (read before citing)
docs/findings/        store protocol reverse-engineering archive (advanced, not needed day to day)
apps/qrwatch/         QR code app: source + prebuilt bundle.pkg
apps/library-qr/      ecosystem example: library reader card dynamic code (generated offline)
apps/purrlaunch-ows/  OWS adaptation delta for PurrLaunch (advanced: desktop entry)
devices/              gx device configs (466×466 round screen)
tools/guiyuan-assistant/  Guiyuan Assistant APK mirror + notes (release page, version, checksum)
tools/ftprobe/        protocol probe (advanced: desktop icon registration)
tools/pkg_tool.py     .pkg container format reader/writer
```

## Key conclusions (pitfalls distilled)

1. **`icon` in the manifest is required** - without it the real device reports 5005, while the emulator runs it anyway
2. **The desktop menu is hardcoded** - for a third-party app to appear on the desktop, it can only take over an existing slot (PurrLaunch disguised as Wooden Fish)
3. **Desktop icons are data-driven** - the store sends a separate `icon_<package name>` on install; for sideloading you must add this step
4. **The store protocol channel cannot install self-made packages** - a working transport layer does not help; sideloading goes through the assistant's debug channel
5. **The "check install" interface has unreliable semantics** - trust only the return codes of install / launch

## FAQ

- **Getting 5005 invalid package?** Nine times out of ten the manifest is missing `icon`.
- **Getting 5001 The package was not found?** The package was not installed or the package name is misspelled (a "check install" result of true does not count).
- **Desktop shows a gear?** The icon registration is missing; this is an advanced item and does not affect running.
- **`adb push` succeeded but the package is not in the assistant's "Download"?** The media scan step was skipped - `ows.py install` does it automatically.
- **Phone cannot connect to the watch?** The watch disconnects in deep sleep; wake it physically, then reopen the assistant and tap "连接" (Connect).
- **The assistant says a new version 1.3 is available, should I upgrade?** This repo was verified end to end on **1.2**; 1.3 only says "supports OHealth" and has not been regression tested, so behavior after upgrading is unknown.

## Acknowledgements and references

- [purrrock/PurrLaunch](https://github.com/purrrock/PurrLaunch) (MIT) - original author of the placeholder launcher; `apps/purrlaunch-ows/` is its OWS adaptation delta
- [pgyer.com/glyphix-assistant](https://www.pgyer.com/glyphix-assistant) - the **original release page** of Guiyuan Assistant (distributed via Pgyer, package name `com.glyphix.assistant`; the page does not name an author)
- [bandbbs.cn/threads/29508](https://www.bandbbs.cn/threads/29508/) - OWS sideloading tutorial (tutorial author libiao0418)
  > The author of that thread is the **tutorial author**, not the author of Guiyuan Assistant (merely a user of the tool). For the Guiyuan Assistant release page, see the previous item.
- [glyphix-os/web-docs](https://github.com/glyphix-os/web-docs) - official Glyphix documentation

> The provenance and verification date of each external resource, and "which fields can be checked and which cannot be found", are recorded in [docs/SOURCES.md](docs/SOURCES.md).

## License and third-party resources

- The **original parts** of this repo (docs, `tools/ows.py`, `apps/qrwatch`, `apps/library-qr`, `tools/pkg_tool.py`, `tools/ftprobe`, `devices/`):
  [MIT](LICENSE), Copyright (c) 2026 chengchengking.
- `apps/purrlaunch-ows/`: upstream [purrrock/PurrLaunch](https://github.com/purrrock/PurrLaunch) is MIT; this directory is its adaptation delta and is likewise used under MIT.
- The APK in `tools/guiyuan-assistant/`: **copyright belongs to the tool's author** and the repo's MIT license does not apply to it. This repo only mirrors it for reproducibility,
  the original release page is [pgyer.com/glyphix-assistant](https://www.pgyer.com/glyphix-assistant); if the author asks for removal, contact the repo maintainer and it will be removed.
- OPPO / Glyphix trademarks and system components belong to their respective owners; this repo contains none of their proprietary code.

## Disclaimer

For research and interoperability on your own devices only. The reverse-engineering notes describe behavior observed on a personal device and contain no proprietary code;
the Guiyuan Assistant APK is copyrighted by its author and is mirrored by this repo only for reproducibility; any risk arising from using this repo's content is borne by the user.

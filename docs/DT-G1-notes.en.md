# DT G1 smartwatch: technical notes and work log

Last updated: 2026-11-05. Keep this file up to date when work continues.

## 1. Goal

Turn the watch into a fitness watch with an audio player:

1. No video.
2. No preloaded images. Some are immodest and the watch refuses to delete them as "system images".
3. No games.

Preferred end state: fully blocked. Accepted first step: hidden from the menu.

## 2. Device facts

| Item | Value |
|---|---|
| Model string | `C175R` |
| Bluetooth name | `GPS WATCH` |
| Firmware | `1.80.54-88318R` |
| UI version | `V1.26.34` |
| Build number used by the vendor API | `88318` (`devicePlan=10`) |
| Vendor adapter id | `1267` |
| Chip vendor | Actions Semiconductor, confirmed by USB vendor id `10D6` |
| Chip model | Expected ATS3085S, not read from the device itself |
| OS | Glyphix on Zephyr RTOS |
| Companion app | WearPro 3.8.6.3 (`com.dtno1.WearPro`) |
| Phone used | Samsung SM-A075F, Android 16, the app is not debuggable |

Vendor capability flags seen in the WearPro logs: `fwUpdate=false`, `game=false`, `application=false`, `convertVideo=true`, `musicTransfer=true`, and dial types `photo_album`, `move_photo_album`, `move_video_album`.

Important: the watch supports video watch faces, so hiding the Video menu entry alone does not remove every route to video.

## 3. USB modes

| Mode | USB id | What Windows sees |
|---|---|---|
| Charging mode, set in the watch settings | `VID_10D6&PID_B00A` | USB serial port, the number can change (COM8 here) |
| Normal Mass Storage | Shown as `ZEPHYR USB DISK` | One drive only, the user storage |
| Real disks, after `AT+WRX=realUpan` and `AT+WRX=mass` | `VID_10D6&PID_B00B` | Two drives, here D: and E: |

Observed behavior:

- After `AT+WRX=mass` the serial port disappears.
- After unplugging and replugging, the watch returned as a disk with both partitions, and no serial port. The drive letters took more than a minute to appear.
- To get the serial port back, set USB mode to Charging mode again in the watch settings, then reconnect.

## 4. Storage layout

The disk is 3.68 GB, MBR, with two FAT32 partitions.

| Partition | Size | Letter here | Watch path | Purpose |
|---|---|---|---|---|
| 1 | about 3.3 GB | D: | Unknown | User storage |
| 2 | about 367 MB | E: | `/1:/` (Glyphix rootfs) | Hidden system partition |

Internal notes from community docs: `internal://mass/` maps to `/1:/data/mass/`. This is from documentation, and the path was not tested here.

### Partition 1 (D:)

| Folder | Content |
|---|---|
| `MAP/map/map_*` | Offline maps, `.mlp`, `.idx`, `.db`, `map.name` |
| `MAP/track` | Tracks |
| `music` | MP3 files |
| `video`, `show_video` | Video files, with the same names and sizes in both folders |
| `course_video` | Empty |
| `photo` | Image container with user photos, for example `photo_3efa.res` |
| `Record` | Recorder, empty |
| `temp` | Temporary files |
| `1165_debug_log` | System log, could not be read from Windows |

`photo_*.res` format, as observed: a 16 byte header, then a full size JPEG (466x466), then a thumbnail JPEG. The first bytes of the header were `09 00 69 c6 01 d2 21 1d`. The meaning of the header fields is unknown.

### Partition 2 (E:)

| Folder | Size | Content |
|---|---|---|
| `gui/apps` | 24.7 MB | 35 Glyphix apps, `.pkg` files, container magic `CR` (`43 52`), not ZIP |
| `gui/fonts` | 20.2 MB | TTF and FNT fonts |
| `gui/font-faces` | Small | Font configuration |
| `ring` | 2.5 MB | Ringtones and system sounds |
| `battery` | 0.9 MB | `battery.txt` |
| `res` | 0.2 MB | `user_clock_bg.bin`, `user_clock_thumb.bin`, background of the current custom watch face |
| `data` | Small | Settings: `g_clock_*`, `sports_*.hex`, `user_nvdm`, `wrist_band_data` |
| `data/mass` | Small | `APIConfig.json`, see section 8 |
| `icoe` | 0.1 MB | GPS `ephemeris.pgl` |
| `logs` | Small | `glyphix.log` |
| `temp` | 0.1 MB | Temporary files |
| `sport` | Empty | |
| `custom` | Empty | Created by us for the menu file |
| `$RECYCLE.BIN` | 7.7 MB | Old factory files, including `video_clock_bg.bin` |

Apps found in `gui/apps`:

- `cc.xuanqi.dict`, `cc.xuanqi.read`, `cn.ticktick.task.watch`, `com.ticktick.task.watch`
- `com.dtno1.aidials`, `app-store`, `audio-book`, `english`, `history`, `movie`, `pilgrimage`, `podcast`, `stock`, `trip`, `wxReply`
- `com.github.linereply`, `com.github.whatsappreply`
- `com.xfaith.al-notes`, `bbc-news`, `buddhabeads`, `calendar`, `chatgpt`, `deepseek`, `ifeng-finance-news`, `map`, `netease-cloud-music`, `sina-news`, `translate`, `travel`, `weather`, `weibo-hot-search`, `wenxinyiyan`, `woodenfish`, `ximalaya`
- `launcher.app`

### Where the preloaded images are

No image files were found on either partition except the user's own. The watch calls them system images and refuses to delete them. The conclusion is that they are most likely inside the firmware. This has not been proven, since no firmware file of this build is available.

## 5. Firmware

- Update check: `https://dt1pro.wanruxia.com/xky-api/firmware/checkUpdate?devicePlan=10&number=88318`
- For build 88318 it returns `data: null`, so no firmware file is published. WearPro uses the same address.
- Firmware for other builds is available, for example 88265 (C175GA3) and 88317 (C229G). Do not flash them. They are for other builds, and may only be studied as a reference.
- OTA format (according to `ATS3085S_firmware_packer`): an AOTA container with no signature, protected only by CRC32. It contains `ota.xml`, `TEMP.bin`, `sdfs_a.bin`, `sdfs_k.bin`, and an inner image with `app.bin` and `sdfs.bin`.
- The tool was documented on version 1.73, and the format of 1.80 was not verified.
- Flashing: `BT_ota_flasher.py` is marked by its author as not working. The WearPro route needs request interception, using HTTP Toolkit on a rooted phone or emulator.
- Dumping: no documented method was found for reading the full flash of this chip. Generic Actions ADFU tools exist, but they were not verified on this watch, and at least one of them erases flash. Do not use them without research.

Check the update address periodically. If a file appears for 88318, download it before anything else, since it opens the way to removing the images.

## 6. Tools

| Tool | Location | Purpose |
|---|---|---|
| `tools/mount_real_disk.ps1` | Project | First script we wrote. Sends the mount commands to one fixed port |
| `tools/watch_at.ps1` | Project | Sends any AT commands, and finds the port automatically |
| `tools/purrlaunch_v1.2.2/ser_set_real_u_py2.exe` | Project | Factory tool. Never executed, see below |
| `tools/purrlaunch_v1.2.2/dtg1-menu-editor/` | Project | Menu editor, `dtg1_menu_editor.exe`, app id list, factory menu sample |
| `tools/dtg1_menu_editor.py.txt` | Project | Editor source, for reading |

Sources:

- https://github.com/purrrock/PurrLaunch
- https://github.com/purrrock/dtg1-menu-editor
- https://github.com/purrrock/ATS3085S_firmware_packer
- https://github.com/purrrock/dtg1-glyphix-docs
- https://github.com/purrrock/dtg1-map-tools

### AT protocol

- Serial settings: 2000000 baud, 8N1, DTR and RTS on.
- Every command is ASCII text followed by the bytes `00 64 00 61`. This odd suffix was copied from the factory tool. Community reports show that plain typed commands in a terminal only return `OK` and do nothing.

| Command | Effect |
|---|---|
| `AT+WRX=always` | Connection check, returns `OK` |
| `AT+WRX=realUpan` | Selects real disks |
| `AT+WRX=mass` | Starts USB storage, the serial port disappears |
| `AT+WRX=saveMenu` | Writes `custom/menu_list.cfg`, not yet tested here |

### Menu file `menu_list.cfg`

- Exactly 1600 bytes, 100 slots of 16 bytes each, little endian.
- Each slot: `AppID`, `IconID`, `NameID`, `Flags`. Flag 1 means visible, 0 means hidden.
- A broken file can cause a boot loop.

Entries to hide:

| AppID | Name |
|---|---|
| `0xCAA2` | Picture |
| `0xC759` | VideoScreen |
| `0xC9EE` | GamesScreen |
| `0xCA8A` | LifeCamera (optional, its function was not verified) |

## 7. Work log

1. Confirmed the model and build from the About screen.
2. Inspected D: read only. The user's own files are there, with no preloaded images.
3. Queried the update address: no firmware for 88318.
4. Copied the WearPro APK to the PC and read its logs with adb. This confirmed Glyphix and gave the capability flags.
5. Downloaded the tools. Hashes matched the GitHub release, and ESET found nothing.
6. Read the factory tool as data. It is a small Python script that sends three AT commands. Running it directly was blocked by the Claude Code safety system, so its commands were sent from our own script instead.
7. Set USB mode to Charging mode. The port appeared as COM8.
8. Sent the mount commands. The watch answered `OK` and E: appeared.
9. Backed up E: to `backup/E_hidden_2026-11-05`, 122 files. `System Volume Information` was skipped.
10. Searched the backup for images: none found.
11. Created the empty folder `E:\custom`.
12. After reconnecting, the watch came back as disks with no serial port.
13. Set Charging mode again and ran `saveMenu`. The watch wrote a 1600 byte `custom/menu_list.cfg`, saved in `backup/menu_original`.
14. Built `backup/menu_edited/menu_list.cfg` with `tools/menu_hide.py`, hiding Picture, VideoScreen, GamesScreen, LifeCamera and PeriodTracking (`0xC841`). Exactly 5 bytes differ from the original.
15. Copied the edited file to `E:\custom\menu_list.cfg`. The SHA-256 of the copy on the watch matched. The result on the watch after a restart was still to be checked at the time of writing.

To undo the menu change, copy `backup/menu_original/menu_list.cfg` back to `E:\custom\` and restart the watch.

16. Confirmed with `saveMenu` that the running menu equals our file. A factory reset kept the menu changes and the music.
17. Hid seven more entries: Contacts, Recents, Messages, DialPad, SportsCourses, MobileVoiceAssistant, FindDevice.
18. Installed the official toolchain in `tools/glyphix-toolchain` (`glyphix-cli` 0.8.0-rc, `gx` v0.11.0). The watch runs Glyphix Nucleus v0.8.0-rc, so versions match.
19. Built `apps/whose-watch`, a screen shown as one PNG, because the fonts in `gui/fonts` have no Hebrew. The font is Varela Round (OFL).
20. Replaced `gui/apps/com.xfaith.woodenfish.pkg` with our app and changed slot 37 (WatchTips) to AppID `0xC82C`.
21. The app opened as a black screen. The log showed `Failed to open package database: /gui/pkgs.db` on every boot.
22. Created `gui/pkgs.db` with one entry for `com.xfaith.woodenfish`. After a restart the app displayed correctly and the rest of the menu worked. Proof of concept succeeded.

### How to build and install an app

1. Device profile: `apps/whose-watch/dtg1-c175r.yml`, with `vendorID: 0x0102` and `productID: 0x0005`, matching the stock packages. Copy it and `image-convert-pal.scm` to `%APPDATA%\glyphix\devices`.
2. Put the toolchain `bin` folder on `PATH`, then run `gx build -d dtg1-c175r -f` in the app folder.
3. Use the package name `com.xfaith.woodenfish` so the hardcoded menu slot works, and include `icon` in the manifest.
4. Set Charging mode, reconnect, mount the disks, copy the `.pkg` to `E:\gui\apps`, restart the watch.
5. The emulator works with `gx emulate -d generic-watch-466x466 --target=com.xfaith.woodenfish`. The custom device profile has no emulator files.

Notes:

- The USB mode returns to Mass Storage after every restart, so select Charging mode again before each upload.
- The menu shows the built-in name of the AppID, "Beat Wooden Fish" in Hebrew. `NameID` and the manifest name did not change it.
- To remove the app: restore the stock package from the backup, delete `gui/pkgs.db`, and restore `backup/menu_v3_12hidden/menu_list.cfg`.
- `tools/glyphix-toolchain` is a local install, and the device profile is also in `%APPDATA%\glyphix\devices`.

Changes now on the watch: the `custom` folder with our menu file, our app replacing `com.xfaith.woodenfish.pkg`, and `gui/pkgs.db`.

## 8. Warnings

- `data/mass/APIConfig.json` contains vendor access keys for cloud services such as Tencent and Baidu. They ship with the watch and are not the user's. Do not use them and do not publish the backup.
- WearPro logs on the phone contain account details. Do not share them.
- Do not edit `pkgs.db` or remove `.pkg` files without a backup and a tested restore.

## 8a. App packages and reference firmware findings

### Package format (`.pkg`)

Per `docs/PKG_FORMAT.md` in `chengchengking/oppo-watch-s-sideload`, confirmed by parsing all 35 packages here with `tools/pkg_list.py`:

- A flat `CR` archive: 32 byte header, a table of 16 byte entries (FNV-1a name hash, offset, size, name length), a name area, then data aligned to 32 bytes.
- No signature, no content checksum, no encryption and no compression.
- `manifest.json` is a binary manifest, `.js` is compiled bytecode (starts with `f2 da 50 01`), `.uo` is compiled UI (starts with `42 b7 01 00`), and `.png` files are stored as they are.
- Replacing images is therefore simple. Changing logic needs the Glyphix toolchain (`glyphix-cli` / `gx`) or bytecode work.

### Where the images are not

A scan of all files on partition 2, including inside packages, found no gallery app. The JPEG signature hits were false matches in fonts, app icons, or the user's own files. No package contains the words album, gallery or photo in `launcher.app`. Pictures and Video are native screens inside `app.bin`, not packages.

### Reference firmware

Build 88265 (C175GA3) was downloaded and parsed as data only. It is not this watch's firmware, and must never be flashed. Findings may differ on 88318.

- `app.bin` has strings with `defaultCount` and `photoCount`, and `read_photo_list_from_depth_nand`, so the code separates default photos from user photos.
- `/0:/` is the user partition and `/1:/` the system partition. `/1:/custom/menu_list.cfg` is confirmed.
- `sdfs_a.bin` holds LZMA compressed chunks. Decompressed, it has a table of 11 files: `video_res` (3 JPEGs of 200x200), `sec_res` (100 JPEGs of 466x466), `c2261_res` (50 JPEGs of 466x466), and other resources.
- Working assumption: default photos sit in this `sdfs` resource area, which neither D: nor E: exposes. The JPEGs were not viewed, so this is not proven.

AT commands seen in the firmware: `dump`, `showlog`, `hidelog`, `always`, `realUpan`, `hideUpan`, `partUpan`, `mergeUpan`, `mass`, `reboot`, `adfu`, `jtag`, `clockTest`, `imgTest`, `saveBat`, `coreDump`, `nvram`, `getNvram`, `gcid`, `screenShot`, `clearInfo`, `saveMenu` and others.

Do not send these without studying them in `app.bin` first: `partUpan` and `mergeUpan` ("part flash", "merge flash") may change the partitions, `clearInfo` clears data, and `adfu` and `jtag` change boot or debug state. `dump` and `coreDump` might help read memory, but their behavior is unknown.

## 9. Current status (2026-11-05)

Done and stable on the watch (survived a factory reset):
- 12 menu items hidden in `menu_list.cfg`: Picture, VideoScreen, GamesScreen, PeriodTracking, LifeCamera, Contacts, Recents, Messages, DialPad, SportsCourses, MobileVoiceAssistant, FindDevice.
- Our own app ("Whose watch?") installed in the Wooden Fish slot (AppID `0xC82C`), registered via `gui/pkgs.db`.
- The preloaded images stay inside the firmware (hidden from the menu only). The watch calls them system images and will not delete them, and no firmware file for build 88318 is available, so physical removal was not achieved.

Backups:
- `backup/menu_original` - the factory menu dump.
- `backup/menu_edited`, `menu_v2_5hidden`, `menu_v3_12hidden`, `menu_v4_app` - menu versions.
- `backup/E_hidden_2026-11-05` - full copy of the hidden partition (partition 2 / `/1:/`).

## 10. Firmware deep dive

Details in `docs/firmware-analysis/` (English, with `.he.md` Hebrew copies):
- `debug-command-table.md` - the full debug command table, 31 entries, each mapped to its handler address. Load base `0x10000000`. Two groups: the reachable `xky` group (saveMenu, mass, realUpan, showlog, memDump, clearInfo, adfu...) and the unreachable `dbg` group (dumpbuf, fread spi_flash).
- `dump-commands-analysis.md` - per-handler disassembly of the dump-related commands. `memDump` only prints memory stats (safe). `dump`/`coreDump` are handled outside `app.bin` (unknown). A full dump is possible via the `dbg` command `dumpbuf <addr> <len> <path>` or `fread spi_flash`, but only from the `dbg` shell, which the `AT+WRX=` channel does not reach.
- Package format: `.pkg` is an unsigned flat "CR" archive (32-byte header, 16-byte entry table with FNV-1a name hashes, name area, 32-byte-aligned data). No signature, checksum, or encryption. `.js` is compiled bytecode, `.uo` compiled UI, `.png` stored in PGF format.
- OTA format: AOTA container, unsigned, CRC32 only; `TEMP.bin` holds XZ-compressed chunks -> inner AOTA -> `app.bin` (Zephyr + Glyphix) + `sdfs`. Reference firmware 88265 was unpacked as data only (never flashed). Its `sdfs_a.bin` holds a `sec_res` of 100 screen-size JPEGs and a `c2261_res` of 50 more; the default/system images most likely live in this resource area.

Commands never to send: `partUpan`, `mergeUpan`, `testWrite`, `testReplaceData`, `delClock`, `clearInfo`, `ota`, `ramdump`, and ADFU flash with erase.

## 11. ADFU firmware-dump journey and conclusion

Full log in `docs/firmware-analysis/adfu-dump-attempt.md`. Summary:
- The watch enters ADFU boot-ROM download mode (USB `10d6:10d6`) with `AT+WRX=adfu`. Reversible by a power-cycle.
- The boot ROM has a read-only memory read command (CBW `0xCD 0x93`). Flash is XIP-mapped at `0x10000000`, so a read-only dump is possible in principle.
- Windows wall: the ADFU device stays only about 6 seconds; Windows cannot bind WinUSB within that window (even with a pre-staged driver via Zadig "Device -> Create New Device"; the registry Service stayed empty); and the watch does not return to Charging mode on its own, so automatic retry is impossible.
- Even a successful dump would not enable safe image removal, because that needs reflashing and there is no 88318 recovery image.
- Viable path not taken: native Linux, where libusb opens the device from usbfs the instant it appears, beating the 6-second fuse with one self-contained script. WSL does not help (usbipd hits the same bind race).

## 12. Full tools inventory

`tools/`:
- `watch_at.ps1` - send AT commands to the watch (Charging mode), auto-finds the COM port.
- `watch_at_read.ps1` - send AT commands and print the serial reply (read-only probe).
- `mount_real_disk.ps1` - the first mount script (fixed port).
- `adfu_keepalive.ps1` - re-enters ADFU repeatedly (not needed now).
- `menu_hide.py` - clear the visible flag for given AppIDs in `menu_list.cfg`.
- `pkg_list.py` - list and extract Glyphix `.pkg` (CR) archives.
- `dtg1_menu_editor.py.txt` - the community menu editor source (reference).
- `purrlaunch_v1.2.2/` - community tools (menu editor exe, `ser_set_real_u_py2.exe`). Hashes matched GitHub, ESET clean.
- `glyphix-toolchain/` - the official Glyphix CLI (`gx` v0.11.0) installed locally, for building apps.
- `adfu-dump/` - `adfu_read.py`, `adfu_dump_win.py`, and `pylibs` (pyusb, libusb-package, pyserial) for the ADFU dump.

`apps/whose-watch/` - our proof-of-concept app (source, device profile `dtg1-c175r.yml`, `dist/com.xfaith.woodenfish.pkg`).

## 13. How to continue

- Get the firmware file via native Linux: send `AT+WRX=adfu` over the serial port, then immediately open `10d6:10d6` via libusb and read from `0x10000000` upward with CBW `0xCD 0x93`. The protocol and a Windows reader are in `tools/adfu-dump/`; on Linux, pyusb opens the device directly, no WinUSB or Zadig needed.
- Change the menu again: dump with `AT+WRX=saveMenu`, edit with `tools/menu_hide.py` (keep exactly 1600 bytes), copy back to `E:\custom`, restart.
- Build another app: see "How to build and install an app" above.
- Watch the vendor server for a firmware update for build 88318. If one appears, download it first and keep it as a recovery image.

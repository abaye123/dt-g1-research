# Reverse-engineering inputs

Local-only material used for analyzing the watch and its companion app. The binaries here are third-party and are gitignored (not committed). This README is tracked so the folder's purpose is recorded.

## wearpro-apk/

The WearPro companion app (`com.dtno1.WearPro`), pulled from the paired phone over adb (version 3.8.6.3). Kept for reverse-engineering the features WearPro offers, so the `dt-g1-studio` tool can reach feature parity (for example editing watch-face backgrounds and transferring images). Files:
- `base.apk`, `split_config.arm64_v8a.apk`, `split_config.xhdpi.apk`
- `split_config.iw.apk` - the Hebrew (`iw`) resources split; useful for UI strings.

How it was obtained: `adb pull` of the installed package paths. To refresh: `adb shell pm path com.dtno1.WearPro` then pull each path.

Note: the app's logs on the phone and some responses contain account data (email, tokens) and vendor cloud keys. Do not commit extracted strings without filtering those out.

## ref-firmware-88265/

Extracts from the reference OTA firmware of a near model (build 88265, C175G). This is NOT this watch's firmware (ours is 88318) and must never be flashed. Used as a read-only reference to map the command table, the dump handlers, and the resource layout. Files:
- `app.bin` - the executable kernel (Zephyr + Glyphix, ARM Thumb-2), load base `0x10000000`.
- `sdfs_a.bin.dec`, `sdfs_k.bin.dec` - decompressed system resource file systems. `sdfs_k` holds `harmony.ttf` (the system font, which includes Hebrew) and the language files (`m_he-il.hex`).

The analysis written from these lives in `../docs/firmware-analysis/`.

## Provenance / legality

These are inputs for interoperability and personal-device customization research on hardware the owner possesses. They are kept local and out of version control.

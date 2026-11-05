Source repository: https://github.com/purrrock/ATS3085S_firmware_packer (MIT). This is an unofficial translation.

# ATS3085S Firmware Packer / Unpacker

A set of Python utilities for reverse engineering, unpacking, modifying and repacking OTA firmware of smartwatches based on the **Actions Semiconductor ATS3085S** hardware platform (Glyphix OS / Zephyr RTOS), such as the **DT NO.1 G1** and similar devices.

This toolkit lets you get past the proprietary "matryoshka" structure of `AOTA` containers, extract system resources (VFS) and the kernel (`app.bin`), apply patches and generate a 100% valid OTA image for flashing over Bluetooth (BLE).

---

## ⚠️ Disclaimer
**This tool is intended solely for research and educational purposes.** Incorrect modification of the OS kernel, system flags or the interrupt vector table (IVT) may lead to "bricking" (hard-brick) your device. Use at your own risk.

---

## Architecture features

Updates for the ATS3085S platform are delivered as unencrypted containers. Integrity protection is built solely on a cascade of **CRC32 (zlib)** checksums.

The firmware is a three-level matryoshka:
* **Layer 1 (Outer AOTA):** The main container (`.bin`) holding the `ota.xml` metadata, UI resources (`sdfs_a.bin`, `sdfs_k.bin`) and the bootloader image.
* **Layer 2 (TEMP.bin bootloader):** A binary file made of a boot header (`ACTHHTCA`), a hardware Boot Stub and a continuous stream of XZ-compressed chunks (2 MiB each).
* **Layer 3 (Inner AOTA):** A monolithic image obtained after decompressing all XZ chunks. It contains the executable kernel `app.bin` (Zephyr + Glyphix) and system configs.

> Detailed technical information about the formats and algorithms is available in the `docs/` directory.

---

## Repository structure

* `aota_full_unpack.py` - The main pipeline for full recursive unpacking of the firmware down to the kernel layer.
* `aota_full_pack.py` - The main pipeline for reverse cascade assembly of modified files into a ready OTA image.
* `BT_ota_flasher.py` - A script for flashing the assembled `.bin` file into the watch over Bluetooth Low Energy (BLE). It does not work yet, debugging is in progress.
* `tools/` - Low-level utilities for manual debugging of each layer (FAT unpackers, XZ decompressors).
* `docs/` - Reverse engineering documentation.

---

## Usage instructions

### Requirements
* Python 3.8+
* No third-party dependencies for building (only the standard libraries `struct`, `lzma`, `zlib` are used).

### 1. Unpacking the original firmware
Feed the original update file (how to download the factory OTA firmware is described in How-to_flashing.md) to the main unpacker:

```bash
python aota_full_unpack.py original_firmware.bin
```

The script will create the following directory structure:
```text
original_firmware_extracted/                  <-- Layer 1
├── ota.xml
├── version.txt
├── sdfs_a.bin
├── sdfs_k.bin
└── TEMP_extracted/                           <-- Layer 2
    ├── actions_boot_header.bin
    ├── boot_stub.bin
    └── inner_aota_extracted/                 <-- Layer 3 (Target folder for modding)
        ├── ota.xml
        ├── app.bin                           <-- Executable kernel (ARM Thumb-2)
        └── sdfs.bin
```

### 2. Modification (Modding)
You can edit files of the filesystem or disassemble `app.bin` (Ghidra / IDA Pro), apply ARM Thumb-2 patches and save app.bin back into the `inner_aota_extracted/` directory.

*Note: If you want to change the firmware version so that the watch accepts a downgrade or a custom build, edit the `build_ver` value in the `version.txt` file (in the root of `original_firmware_extracted/`). The build utility will automatically patch all `ota.xml` files.*

### 3. Building the modified firmware
Specify the root directory of the extracted firmware and the output file name:

```bash
python aota_full_pack.py original_firmware_extracted/ custom_firmware.bin
```

The script will automatically:
1. Align the size of `app.bin` to 512-byte sectors.
2. Assemble the Layer 3 monolith.
3. Cut the monolith into 2 MiB blocks and compress them into XZ format.
4. Glue on the Boot Stub and assemble a valid `TEMP.bin` (Layer 2).
5. Update all sizes and CRC32 values inside `ota.xml`.
6. Generate the final AOTA container (Layer 1).

### 4. Flashing the device
Instructions for loading the finished `custom_firmware.bin` into the watch are in the file [How-to_flashing.md](How-to_flashing.md).

---

## Documentation (Docs)

* [Structure of the main AOTA container](docs/structure_OTA.md)
* [Internal architecture of the TEMP.bin bootloader (Stage-2)](docs/structure_TEMP_bin.md)
* [Analysis of the WearPro Bluetooth OTA protocol](docs/Bluetooth_OTA_protocol.md)

---

## License
This project is distributed under the MIT license. See the [LICENSE](LICENSE) file for details.

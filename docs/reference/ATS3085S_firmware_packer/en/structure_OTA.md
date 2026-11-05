Source repository: https://github.com/purrrock/ATS3085S_firmware_packer (MIT). This is an unofficial translation.

# OTA firmware format specification (Actions Semiconductor AOTA)

**Platform:** Actions Semiconductor ATS3085S
**OS:** Glyphix / Zephyr RTOS
**Target device:** DT NO.1 smartwatches and similar

Based on static and dynamic analysis of hex dumps, as well as a successful brute-force of the hashing algorithm, the structure of the OTA container is described below. This revision includes the exact checksum coverage addresses and hardware constants.

---

## 1. General container architecture

The `AOTA` (Actions OTA) format is an unencrypted multi-level archive without a cryptographic signature (RSA/ECC). Security and integrity rely solely on the **CRC32 (IEEE 802.3 / zlib)** algorithm applied in a cascade.

The file consists of four logical zones:
1. **Root Header (Main header)** - 512 bytes (0x0200).
2. **FAT (File Allocation Table)** - 512 bytes (0x0200), starts immediately after the header (holds up to 16 files).
3. **Data Payload** - the files themselves, strictly aligned to sector boundaries.
4. **Tail Padding** - zero bytes up to the sector boundary.

---

## 2. Binary data structures

All multi-byte values are stored in **Little-Endian** format (unless explicitly stated otherwise).

### 2.1. Main header (AOTA Header)

The header always occupies exactly one sector (512 bytes, `0x0200`).

```c
struct aota_header_t {
    char     magic[4];          // 0x000: Magic number "AOTA" (0x41 0x4F 0x54 0x41)
    uint32_t header_checksum;   // 0x004: CRC32 of the header and FAT (calculation range: 0x0008 - 0x03FF)
    uint32_t flags;             // 0x008: Container flags (In the dump: 00 01 00 04)
    uint32_t file_count;        // 0x00C: Number of files in the FAT table (for example, 4)
    uint16_t fat_offset;        // 0x010: Absolute offset of the FAT table (always 0x0200)
    uint16_t data_offset;       // 0x012: Absolute offset of the payload (always 0x0400)
    uint32_t total_file_size;   // 0x014: Total size of the AOTA file including all sector paddings
    uint32_t payload_checksum;  // 0x018: CRC32 of the payload (calculation range: 0x0400 - EOF)
    uint32_t reserved1;         // 0x01C: Reserved (0x00000000)
    uint8_t  padding1[32];      // 0x020: Zero padding up to 0x040
    char     build_ver[32];     // 0x040: Build version and timestamp (null-terminated, max 32 bytes)
    char     platform_id[30];   // 0x060: Platform identifier (null-terminated, max 30 bytes)
    uint16_t hardware_rev;      // 0x07E: Hardware revision of the board (in the dump: 01 00)
    uint8_t  slot_protection[4];// 0x080: System flags for slot A/B or protection (in the dump: 00 00 00 01)
    uint8_t  padding2[380];     // 0x084 - 0x01FF: Zero padding up to the end of the header sector
};
```

### 2.2. File Allocation Table

Located at the offset given in `fat_offset` (by default `0x0200`). It is an array of structures. The number of array elements equals `file_count`. The size of one entry is 32 bytes (`0x20`).

```c
struct aota_fat_entry_t {
    char     filename[16]; // 0x00: File name (null-terminated ASCII). Max 15 characters.
    uint32_t offset;       // 0x10: Absolute offset of the start of the file from the start of the container (0x00000000)
    uint32_t size;         // 0x14: True physical size of the file (excluding sector padding)
    uint32_t reserved;     // 0x18: Reserved (0x00000000)
    uint32_t file_crc32;   // 0x1C: CRC32 (zlib) of the binary data of the current file
};
```

---

## 3. Alignment math (Sector Alignment)

The Actions Semiconductor hardware bootloader works with flash memory in blocks (sectors) of 512 bytes. This imposes strict requirements on the file layout:

1. **Data Offset:** The first file (usually `ota.xml`) always starts at offset `0x0400` (1024 bytes), since sectors `0x0000` and `0x0200` are occupied by the header and the FAT table.
2. **Padding between files:** Each subsequent file inside the archive must start at a new 512-byte sector boundary.
3. **Tail padding:** The end of the last file is padded with zeros to a 512-byte boundary, forming the final container size (`total_file_size`).

**Formula for calculating the next offset in Python / C:**

```python
# SECTOR_SIZE = 512
next_offset = (current_offset + file_size + 511) & ~511
```

The empty space between the end of `file_size` and the computed `next_offset` **must** be filled with zeros (`0x00`).

---

## 4. Checksum algorithms (CRC)

A standard hashing algorithm is used with the following parameters:
* **Algorithm:** `CRC-32 (IEEE 802.3 / zlib)`
* **Polynomial:** `0x04C11DB7`
* **Init (Initial value):** `0xFFFFFFFF`
* **XorOut (Final XOR):** `0xFFFFFFFF`
* **Reflect In / Out:** `True / True`

### Trust Chain and memory coverage zones:

1. **`file_crc32` (FAT):** Computed directly over `file_size` bytes of the file payload (strictly excluding the 512-byte sector padding).
2. **`payload_checksum` (offset 0x018):** Computed from offset `0x0400` to the end of the file (including all files and all paddings). This is the hash of the entire payload.
3. **`header_checksum` (offset 0x004):** Computed from offset `0x0008` to `0x03FF`. This hash covers:
   * The flags and metadata of the header (including the `payload_checksum` written inside it).
   * The entire FAT table (`0x0200` - `0x03FF`).
   * The first 8 bytes of the file (the signature and the hash field itself) are not included in this calculation.

---

## 5. Internal file hierarchy (Matryoshka)

For the ATS3085S platform (DT NO.1) the `AOTA` container has a nested architecture.
The outer level (`ota_...bin`) contains:

* `ota.xml` - metadata for the parser (display ID, build versions).
* `TEMP.bin` - is a **nested archive**. Described in a separate document`).
* `sdfs_a.bin` and `sdfs_k.bin` - System Data File System images (resources, fonts, basic UI components).

### Repacking instructions (Workflow):

1. Parse the outer `AOTA` by the FAT offsets. Export `version.txt`.
2. Extract `TEMP.bin`, find the LZMA signature (`FD 37 7A 58 5A 00`).
3. Decompress LZMA -> obtain the inner `AOTA`.
4. Parse the inner `AOTA`, extract `app.bin`.
5. Make changes in assembler (patching / resource modification).
6. Assemble the inner `AOTA` (recompute the sector alignments, `Payload CRC` and `Header CRC`).
7. Compress the inner `AOTA` back with the LZMA/XZ algorithm.
8. Assemble the outer `AOTA` (embed the new `TEMP.bin`, align sectors, recompute the FAT, `Payload CRC` and `Header CRC`, preserving the hardware constants and the version).

Source repository: https://github.com/purrrock/ATS3085S_firmware_packer (MIT). This is an unofficial translation.

# `TEMP.bin` binary format specification
**Platform:** Actions Semiconductor ATS3085S  
**Software platform:** Glyphix OS / Zephyr RTOS  
**Target device:** DT NO.1 G1 smartwatches and compatible ones  
**Specification version:** 1.6 (Final verified)

---

## 1. General container architecture

The `TEMP.bin` binary file is a proprietary second-stage boot container (Stage-2 Bootable Image Container). The file is intended to be executed by the primary bootloader of the Actions ATS3085S chip, to initialize the hardware peripherals / memory controller and then to decompress the system partitions of the firmware into RAM.

The container consists of five key logical zones:
1. **Actions Boot Header (`ACTHHTCA`)** - 40 bytes (`0x00000000`-`0x00000027`).
2. **Alignment Padding** - 472 zero bytes (`0x00000028`-`0x000001FF`), aligning the IVT to a 512-byte boundary.
3. **Interrupt Vector Table (IVT)** - 320 bytes (`0x00000200`-`0x0000033F`), the hardware interrupt vector table of the ARM Cortex-M.
4. **Boot Stub Code & Padding Gap** - executable Thumb-2 code for primary hardware initialization and an aligning gap up to the first compressed block.
5. **Compressed Payload Chunks** - a sequence of compressed XZ streams that represent the monolithic image of the inner container `inner_aota_container.bin`, sliced into portions of **2 MiB (`0x200000`)**.

---

## 2. Global file memory map (Memory Map)

| Offset (Hex) | End of block | Size (Bytes) | Description / Contents |
| :--- | :--- | :--- | :--- |
| `0x00000000` | `0x00000027` | 40 | **Main boot header** (`ACTHHTCA`) |
| `0x00000028` | `0x000001FF` | 472 | **Alignment filler** (`0x00` bytes) |
| `0x00000200` | `0x0000033F` | 320 | **Interrupt vector table (IVT)** of the ARM Cortex-M |
| `0x00000340` | `entry_point - 1` | Variable | **Boot Stub Engine**: Thumb-2 machine code for hardware initialization |
| `entry_point` | `first_lzma - 1` | Variable | **Padding Gap**: technical aligning gap up to the LZMA section |
| `first_lzma` | `chunk2_start - 1` | Variable | **Chunk #1**: `LZMA` header (16b) + XZ stream (Block #1 of the monolith, 2 MiB / `0x200000`) |
| `chunk2_start` | `EOF` | Variable | **Chunk #2**: `LZMA` header (16b) + XZ stream (Block #2 of the monolith, the remaining bytes) |

---

## 3. C structures of the headers (Little-Endian)

### 3.1. Main Actions Boot Header (40 bytes / 0x28)
Starts at file offset zero (`0x00000000`).

```c
struct actions_boot_header_t {
    char     magic[8];       // "ACTHHTCA" (0x41 0x43 0x54 0x48 0x48 0x54 0x43 0x41)
    uint32_t load_addr;      // Load address of the Reset Vector in XIP Flash (for example, 0x1000246D or 0x100024B1)
    uint32_t block_size;     // 0x00000062 (Size of the header service block, 98 bytes)
    uint32_t padding;        // 0x00000000 (Zero filler)
    uint32_t exec_addr;      // Execution entry point in memory (matches load_addr)
    uint32_t entry_point;    // Absolute offset of the boundary of the executable Boot Stub code (for example, 0x00011028)
    uint32_t header_sig;     // Factory static header signature (for example, 0xCA99494D)
    uint32_t payload_sig;    // Factory static payload signature (for example, 0x8BCDC3C5)
    uint32_t ivt_offset;     // 0x00000200 (Offset of the start of the IVT vector table = 512 bytes)
};
```

#### Purpose of the key fields:
* **`load_addr` / `exec_addr` (`0x0008`, `0x0014`):** Define the physical start address of the ARM Cortex-M processor in Thumb mode (the low bit equals `1`). The address is unique for each firmware build.
* **`entry_point` (`0x0018`):** Marks the end of the executable Boot Stub section. Between `entry_point` and the first compressed `LZMA` chunk there is a filler (Padding Gap).
* **`header_sig` / `payload_sig` (`0x001C`, `0x0020`):** Factory static signatures of the current build. They are not subject to dynamic recalculation via zlib/SUM32 and are preserved unchanged when repacking.

---

### 3.2. Compressed chunk header Actions LZMA Header (16 bytes / 0x10)
Placed before each compressed block.

```c
struct actions_lzma_header_t {
    char     magic[4];       // Magic bytes "LZMA" (0x4C 0x5A 0x4D 0x41)
    uint32_t header_size;    // Fixed header size: 0x00000010 (16 bytes)
    uint32_t comp_size;      // Physical size of the packed XZ stream in bytes
    uint32_t uncomp_size;    // Declared size after decompressing the block in RAM (limit 0x200000)
};
```

---

## 4. Hardware vector table (IVT)

The vector table is located strictly at offset **`0x00000200`** (`ivt_offset = 0x200`):

* **`0x00000200` (Initial MSP):** Stack pointer in the internal SRAM region of the ATS3085S.
* **`0x00000204` (Reset Vector):** Reset vector (points to `load_addr`).
* **`0x00000208`-`0x0000023F`:** System interrupt handlers of the ARM Cortex-M (NMI, HardFault, SVC, SysTick).
* **`0x00000240`-`0x0000033F`:** Default handlers for the chip's peripheral interrupts.

---

## 5. Payload fragmentation mechanics (2 MiB Chunking)

The `TEMP.bin` container stores **one continuous binary image (`inner_aota_container.bin`)**, which is sliced during assembly into portions of no more than **2 MiB (`0x200000` bytes / 2 097 152 bytes)**.

### Evidence of the cut between blocks:
* **Monolithic image:** Contains the inner AOTA container with the files `ota.xml`, `app.bin` (larger than 3 MB) and `sdfs.bin`.
* **Chunk #1:** Compresses the first `0x200000` bytes of the monolith. Because of this the body of `app.bin` ends up cut: the first `0x001FF800` bytes of the kernel go into Chunk #1.
* **Chunk #2:** Compresses the remaining part of the monolith (`0xFD600` bytes), containing the tail of `app.bin` and `sdfs.bin`.

---

## 6. Tool operating rules (Protocol Standard)

1. **Unpacking (`unpack_temp.py` v1.3):**
   - Reads the 40-byte `actions_boot_header.bin`.
   - Extracts `boot_stub.bin` (from `0x28` to the first strict marker `LZMA\x10\x00\x00\x00`).
   - Expands all XZ streams in memory (In-Memory) and glues them into a single monolith `inner_aota_container.bin`.
   - Intermediate chunks `chunk_*.*` are saved to disk only when the optional flag `-s` (`--save-chunks`) is passed.

2. **Assembly (`compress_and_pack_temp.py` v1.6):**
   - Uses the original 40-byte `actions_boot_header.bin`, preserving the factory addresses and signatures.
   - Writes `boot_stub.bin`.
   - Slices the modified `inner_aota_container.bin` into pieces of `0x200000` bytes, compresses each into XZ and wraps it with an `actions_lzma_header_t` header.
   - Produces the final `TEMP_new.bin`.

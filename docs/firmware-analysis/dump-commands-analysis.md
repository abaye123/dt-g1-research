# Firmware Analysis: AT+WRX Dump / Maintenance Commands

Target file: `ref_fw_88265_DO_NOT_FLASH/app.bin` (reference OTA image from model C175G,
Actions Semiconductor ATS3085S, Zephyr RTOS + Glyphix C++ GUI, ARM Thumb-2, 3203712 bytes).

This is a static, read-only analysis of a local file. No device, USB drive, or network was touched.
All file offsets are given so a human can re-verify in Ghidra or IDA.

Disassembler: capstone, CS_ARCH_ARM / CS_MODE_THUMB.

---

## 1. Load base B

**B = 0x10000000**, with the mapping `vaddr = file_offset + 0x10000000` (file offset 0 maps to 0x10000000).

How it was confirmed:
- Header at offset 0 is `ACTHHTCA`; the 32-bit LE word at offset 8 is `0x100be7b1`
  (entry / reset pointer). `0x100be7b1 - 0x10000000 = 0xbe7b1`, which lands inside the file
  (size 0x30e280), consistent with an entry point in the image. XIP region is 0x10000000+.
- Correlation test: I extracted all 10758 null-terminated ASCII string start offsets, and all
  55449 32-bit LE words that fall in 0x0FFF0000-0x10400000. For every candidate base B, I counted
  how many pointer words satisfy `(pointer - B)` equals the start of a known string. The winner was
  overwhelming:

  | base B       | pointers landing on a string start |
  |--------------|------------------------------------|
  | 0x10000000   | 16230                              |
  | 0x10000880   | 2979                               |
  | 0x1000bfd8   | 2741                               |

  0x10000000 wins by more than 5x over any other base. Confidence: **high**.

- Independent cross-check: shell dispatch tables (see below) hold absolute pointers such as
  `0x102cbfb2`, which under B=0x10000000 resolve exactly onto string starts
  (`0x2cbfb2 = "screenShot"`). Handler pointers are odd (Thumb bit set) and resolve onto valid
  function prologues. This confirms B both for data and for code.

---

## 2. How the commands are actually dispatched (important structural finding)

There are two distinct command surfaces in this image, and they must not be confused:

**(a) The "AT+WRX=..." catalog at file offset 0x30bfac.**
This is a plain array of fixed 30-byte (0x1e) `char[30]` slots:
`AT+WRX=dump`, `AT+WRX=showlog`, `AT+WRX=hidelog`, `AT+WRX=always`, `AT+WRX=realUpan`,
`AT+WRX=hideUpan`, `AT+WRX=partUpan`, `AT+WRX=mergeUpan`, `AT+WRX=mass`, `AT+WRX=reboot`,
`AT+WRX=adfu`, `AT+WRX=jtag`, ... `AT+WRX=coreDump` (0x30c1e6), ... `AT+WRX=saveMenu` (0x30c38a).

Key result: **none of these catalog strings (and none of their `+7` suffixes) is referenced
anywhere in app.bin.** I checked exhaustively for:
  - absolute 32-bit pointer words equal to each string vaddr (literal pools) -> 0 hits;
  - `movw`/`movt` immediate pairs that build each string vaddr -> 0 hits.

Therefore this 0x30bfac block is a **documentation / help catalog only**. The code that parses an
incoming `AT+WRX=<x>` line and decides what to run is **not present in app.bin**. The `AT+WRX=...`
strings that *are* referenced live elsewhere (e.g. `AT+WRX=screenShot` at 0x2cbfab is referenced at
file offset 0xef6bc) and they are used by **senders**: functions that *emit* an `AT+WRX=...` message
to a service named `system_service` (dispatcher at 0xfce10). Markers `WRX_CYFIT_BLE`,
`WRX_CYFIT_SPP`, `WRX_CYFIT_UART` (0x2ad3fb) show the WRX channel is carried over BLE / SPP / UART,
so the actual `AT+WRX` interpreter is a separate component (companion / BT side / host tool / ROM),
not this kernel image.

**(b) The Zephyr shell command tables (the real handlers in this image).**
These are `struct shell_static_entry { const char* syntax; const char* help; const void* subcmd;
shell_cmd_handler handler; u8 mand; u8 opt; }`. I enumerated them across the whole file. The
relevant group is `xky` ("xky custom commands", root string at 0x2b7ec2), whose leaf entries
include `memDump`, `showLog`, `screenShot`, `saveMenu`, `partUpan`, `mergeUpan`, `mass`,
`clearInfo`, `reboot`, `showFlash`. A separate `dbg` group (root at 0x2b7804) holds the raw
memory/flash primitives: `mdw/mdh/mdb` (read memory), `mww/mwh/mwb` (write memory), `fread`
(read flash), `dumpbuf` (dump memory to a file), `ramdump` (dump ram to flash), `snort` (nor test).

The names in the `xky` group overlap the `AT+WRX=` catalog (screenShot, saveMenu, partUpan, mass,
showlog/showLog, clearInfo), which strongly suggests the external parser forwards
`AT+WRX=<x>` to the Zephyr shell command `xky <x>`. Under that model the handlers below are what
actually runs.

Note on the four requested names:
- `memDump` -> real `xky` handler (analyzed below).
- `showlog` -> maps to `xky showLog` handler (analyzed below).
- `dump` -> **no shell command named `dump` exists** in this image (closest unrelated entries:
  `dumpbuf`, `dumpmsg`, `dumpmem`, `memory_dump`). Handler not present. UNKNOWN.
- `coreDump` -> **no shell command named `coreDump` exists** in this image. Handler not present.
  UNKNOWN.

---

## 3. Command-by-command findings

### 3.1 memDump  (AT+WRX=memDump -> xky memDump)

- Shell entry: 0x28f050, name `memDump`, help `cust memory dump`.
- Handler: va 0x10216937, **file offset 0x216936**. It is a thin wrapper:

```
216936  push {r3, lr}
216938  bl   0x102271ac        ; the worker
21693c  movs r0, #0
21693e  pop  {r3, pc}
```

- Worker at **file offset 0x2271ac** calls four routines, bracketed by 0xad228(0) / 0xad228(1)
  (a render/lock suspend-resume pair):

```
2271ac  push {r3, lr}
2271ae  movs r0, #0
2271b0  bl   0x100ad228        ; suspend/lock (arg 0)
2271b4  bl   0x100f3398        ; -> format string "gdi_img_data_list_dump"
2271b8  bl   0x10163838        ; -> prints "JsVM heap stats:" ...
2271bc  bl   0x10146114        ; -> "bitmap_font_cache_dump_info"
2271c0  pop.w {r3, lr}
2271c4  movs r0, #1
2271c6  b.w  0x100ad228        ; resume/unlock (arg 1)
```

- Evidence of intent (string references resolved from the literal pools of the three sub-workers):
  - 0xf3398 references `'gdi_img_data_list_dump'` (0x102ce830) and calls the log-printf at 0x1f392c with level r0=3.
  - 0x163838 references `'JsVM heap stats:'` (0x102e7aa6) and `'  -- sizeLimit: '` (0x102e7ab7).
  - 0x146114 references `'bitmap_font_cache_dump_info'` (0x102e65a7), also via 0x1f392c level 3.
- No file is opened, no flash device is accessed, no address range is read out. It only prints
  Glyphix GUI framework memory statistics (image cache, JS VM heap, font cache) to the log via the
  printf/log function at 0x1f392c.

**Verdict: SAFE-READONLY.** Prints in-RAM GUI memory-usage statistics to the log. No flash read,
no file write, no mode change.

### 3.2 showlog  (AT+WRX=showlog -> xky showLog)

- Shell entry: 0x28eefc, name `showLog`, help `show log`.
- Handler: va 0x1021697f, **file offset 0x21697e**:

```
21697e  cmp  r1, #1            ; argc
216980  mov  r0, r1
216982  push {r3, lr}
216984  bne  0x2169 8e
216986  bl   0x100f906c        ; argc==1: enable-log path, r0 = 1
...
21698e  cmp  r1, #2            ; argc==2: level set via argv[1]
216992  ldr  r0, [r2, #4]
```

- Worker 0xf906c simply stores the byte into a RAM flag:

```
0f906c  ldr  r3, =0x381e378c   ; SRAM control struct
0f906e  strb r0, [r3, #4]      ; log-enable flag
0f9070  bx   lr
```

(Neighbouring accessors at 0xf9078/0xf9084/0xf9094 read/write the same SRAM log-config bits.)
0x381e378c is SRAM (0x381xxxxx), not flash.

**Verdict: MODE-CHANGE-ONLY.** Sets a log-enable / log-level flag in SRAM. No flash, no file,
no USB change.

### 3.3 dump  (AT+WRX=dump)

- Appears only in the 0x30bfac help catalog (`AT+WRX=dump`). No shell command named `dump` and no
  referenced handler exist in app.bin.
- Nearby unrelated commands exist (`dumpbuf`, `dumpmsg`, `dumpmem`, `memory_dump`) but none is named
  plain `dump`, and the catalog entry is not wired to any of them within this image.

**Verdict: UNKNOWN.** The handler for `AT+WRX=dump` is not contained in this kernel image; it is
handled by the external `AT+WRX` interpreter (BLE/SPP/UART companion or ROM). Cannot be confirmed
from this file. Do not assume it is safe.

### 3.4 coreDump  (AT+WRX=coreDump)

- Appears only in the 0x30bfac help catalog (`AT+WRX=coreDump` at 0x30c1e6, suffix `coreDump` at
  0x30c1ed). No shell command named `coreDump`, and the string is referenced nowhere in app.bin
  (verified against literal pools and movw/movt pairs).

**Verdict: UNKNOWN.** No handler in this image. It sits in the catalog next to `adfu` and `jtag`
(low-level recovery entries), which hints it may trigger a CPU core / crash dump handled by the
Actions BROM or a fault handler outside app.bin, but this is **not confirmed** and must be treated
as unknown. Do not run it to "test".

---

## 4. The real dump primitives (the `dbg` shell group)

These are fully present and analyzed. They are reached through the Zephyr shell, not through the
four AT commands above.

### dumpbuf  -  memory range to a file  (handler file offset 0xaa870)
Usage string: `'dumpbuf addr len path'` (0x2b7244). Behaviour:
- `0xc0ff8` = fs_open(path = argv[3], flags 0x12 = CREATE|WRITE) into a stack file object.
- `0x20c274` = strtoul on argv[1] (addr) and argv[2] (len).
- `0xc11ac` = fs_write(file, addr, len)  -> writes the raw memory bytes to the file.
- `0xc1134` = fs_close.
- On success prints `'done dumping to %s'` (0x2b7270); on failure `'fail to open %s'` (0x2b725e).

Because flash is XIP-mapped at 0x10000000, pointing `addr` at the mapped flash dumps flash contents
to a file. This is the single most useful primitive for obtaining an image. **WRITES-A-FILE
(read of memory, write to filesystem).**

### fread  -  raw flash sectors to the console  (handler file offset 0xab2a0)
Usage: `'fread dev_name(sd/spi_flash/spinand) offset'` (0x2b75ac). It binds device `'spi_flash'`
(0x102a7bec) or spinand/sd, parses the offset, allocates 0x200, reads one 512-byte sector and
prints `'fread 512b: offset=0x%x, buf=0x%x'` (0x2b7603). Reads raw flash (bypassing XIP) to the
shell output, one sector per call. **READS FLASH to console.**

### mdw / mdh / mdb  -  display memory  (mdw handler file offset 0x216898 -> 0xab1b0)
Reads memory by word/half/byte and prints it to the console. Read-only memory peek.

### mww / mwh / mwb  -  memory write (fill)
Writes values into memory. Dangerous if pointed at MMIO or live structures. (Not flash program by
itself, but can corrupt a running system.)

### ramdump  -  "dump ram to flash"  (handler file offset 0xaab28)
Writes a RAM region into a reserved flash dump area. **WRITES FLASH.**

---

## 5. Supporting / adjacent handlers of note

- `saveMenu` (xky, handler file offset 0xab8ec) - the worked reference. Opens/writes
  `'/1:/custom/menu_list.cfg'` (0x2b7c78): calls 0xf67ac (remove/prepare) then 0xf5274
  (write 0x640 bytes from SRAM 0x380013d8). Confirms the SDK file-write helper pattern and that
  `/1:/` is the internal user disk and `/0:/` the (SD/mass) disk. **WRITES-A-FILE.**
- `mass` (xky, handler file offset 0x2169c2) - `'enter usb mass mode'`. argc==1 path calls 0xf9048
  then 0x226490; otherwise 0x226448. Switches the device into **USB mass-storage mode**. This is
  what makes the watch re-enumerate as a disk drive on the host. **USB MODE SWITCH.**
- `partUpan` (xky, handler file offset 0xabb54) - `'part flash'`. Logs via `shell_part_upan`
  (0x2b81a0), references drive `'0:'` and the `PART_UPAN` / `USB_DISK_SIZE` strings (0x2b7d5e /
  0x2b7d68); calls partition/format helpers (0x21e7f2, 0xd6d54 with size 0x200).
  **WRITES-OR-ERASES-FLASH (re-partitions the user disk).**
- `mergeUpan` (xky, handler file offset 0xabadc) - `'merge flash'`, `MERGE_UPAN` (0x2b7d31).
  Companion to partUpan. **WRITES-OR-ERASES-FLASH.**
- actlog group: `erase` (handler file offset 0x1021d8) - `'Erase stored actlog'`. Erases the
  stored action-log region. **ERASES FLASH (action-log partition only).**
- `nvram` / `getNvram` / `nvdump` - read/write the NVRAM (factory/config) region. Writing NVRAM can
  change calibration and binding data. Read paths (`nvdump`, `getNvram`) are read-only.

---

## 6. Can we obtain a full firmware / flash dump, and how?

**Yes - but only through the Zephyr `dbg` shell group, not through any of the four AT+WRX commands
requested.** None of `AT+WRX=dump`, `AT+WRX=coreDump`, `AT+WRX=memDump`, `AT+WRX=showlog` reads
flash to a file or to serial; memDump only prints RAM stats, showlog only toggles a flag, and the
dump/coreDump handlers are not even in this image.

The capabilities that *do* produce a dump are:

1. `dumpbuf <addr> <len> <path>` (handler file offset 0xaa870). Dumps a memory range to a file.
   Flash is XIP-mapped at 0x10000000, so:
   - `dumpbuf 0x10000000 0x30e280 /0:/app.bin` would write the mapped app region to the `/0:` disk.
   - To capture more than the mapped app, repeat with other mapped ranges.
   Output lands at the filesystem path you pass; `/0:/` is the external/mass disk, `/1:/` the
   internal user disk. Confirmed by the `'done dumping to %s'` success string.

2. `fread spi_flash <offset>` (handler file offset 0xab2a0). Reads a raw 512-byte flash sector at
   `offset` and prints it to the shell output (serial). It can also target `spinand` or `sd`.
   This reads the raw flash (not just the XIP view), 512 bytes per invocation, to the console.

Both require access to the Zephyr shell. This image shows the shell is bound to the WRX transport
(UART/SPP/BLE markers) and that `AT+WRX=` names map onto `xky <name>` shell commands; the `dbg`
group would be reached the same way if the external parser exposes it. **Whether the shipped device
actually exposes the `dbg` group to the owner over the available transport is not determinable from
this static image - that is the one open question.** If the shell is reachable, `dumpbuf` to the
SD/mass disk is the clean way to get an image dump, and `fread` is the fallback over serial.

---

## 7. Commands to avoid

Do **not** run these on the real device without a verified recovery path (ADFU):

- `AT+WRX=partUpan` / `partUpan` (handler 0xabb54) - re-partitions the user flash disk
  (`part flash`, `PART_UPAN`, `USB_DISK_SIZE`). Can destroy the filesystem layout.
- `AT+WRX=mergeUpan` / `mergeUpan` (handler 0xabadc) - `merge flash`, partition change. Same risk.
- `AT+WRX=adfu` / `AT+WRX=jtag` - force ADFU download mode / enable JTAG. Puts the device into a
  low-level recovery/debug state (handlers not in app.bin; behaviour is ROM-level).
- `AT+WRX=coreDump` and `AT+WRX=dump` - UNKNOWN handlers (not in this image). Do not run to "see
  what happens"; `coreDump` sits next to adfu/jtag in the catalog.
- `ramdump` (handler 0xaab28) - writes RAM into a flash dump area (`dump ram to flash`).
- `mww` / `mwh` / `mwb` - arbitrary memory writes; can corrupt a running system or MMIO.
- actlog `erase` (handler 0x1021d8) - erases the stored action log.
- `nvram <name> <val>` writes (handler 0xab108) - can overwrite calibration / binding data.
- `AT+WRX=mass` / `mass` (handler 0x2169c2) - switches to USB mass-storage mode and the watch
  re-enumerates as a disk. Not destructive by itself, but it is why the device appeared as a drive.

Safe to run (read-only or RAM-only), based on this analysis:
- `memDump` (0x216936) - prints GUI memory stats to the log.
- `showlog` / `showLog` (0x21697e) - toggles log output flag in SRAM.
- `mdw` / `mdh` / `mdb` (0x216898) - read memory to console.
- `fread ... <offset>` (0xab2a0) - reads flash to console (read-only).
- `nvdump` / `getNvram` - read NVRAM to console.

---

## 8. Reproduction notes (offsets for Ghidra/IDA)

- Load the image at base 0x10000000 (offset 0 -> 0x10000000).
- Shell dispatch table (`struct shell_static_entry`, 20-24 byte stride, layout
  `{syntax, help, subcmd, handler(odd Thumb), mand, opt}`): xky group entries at 0x28e828-0x28f104,
  dbg group entries around 0x28ec10-0x28ee80.
- Key handlers (file offsets): memDump 0x216936 (worker 0x2271ac), showLog 0x21697e
  (worker 0xf906c), dumpbuf 0xaa870, fread 0xab2a0, mdw 0x216898, ramdump 0xaab28,
  saveMenu 0xab8ec, mass 0x2169c2, partUpan 0xabb54, mergeUpan 0xabadc.
- Log/printf function: 0x1f392c (r0 = level). Shell print: 0x216120.
- FS helpers: fs_open 0xc0ff8 (flags 0x12 = CREATE|WRITE), fs_write 0xc11ac, fs_close 0xc1134,
  high-level write-file 0xf5274.
- strtoul: 0x20c274 and 0x27852e.
- AT+WRX catalog (help text only, unreferenced): 0x30bfac, 30-byte slots.

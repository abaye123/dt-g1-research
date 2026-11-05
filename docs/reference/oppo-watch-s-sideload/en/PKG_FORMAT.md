> Source: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). This is an unofficial translation.

# Glyphix `.pkg` Container Format Specification

> All conclusions in this document come from byte-by-byte analysis of **real packages produced by the official toolchain**, with causality verified by **controlled experiments**.
> Verification toolchain: `glyphix-cli` 0.8.0-rc → `gx v0.11.0` (npm, Windows x64 prebuilt).
> Reproduction commands are at the end.

---

## 0. One-sentence conclusion

`.pkg` is a **minimal flat archive**: `CR` magic + 32-byte header + fixed-size entry table + name area + data area aligned to 32 bytes.
**No signature, no content checksum, no encryption, no compression.** The entry index key is the FNV-1a hash of the file name.

---

## 1. Overall layout

```
offset          content
────────────────────────────────────────────────────────────
0x00            header (32 bytes)
0x20            entry table (16 bytes × entry count)
                name area  (entry names concatenated back to back, no separators, no NUL)
                padding    (zero fill, aligned to 0x20)
data_start      data area  (each entry's data aligned independently to 0x20)
```

`data_start = align_up(0x20 + count*16 + len(all names), 0x20)`

---

## 2. Header (32 bytes)

| Offset | Type | Meaning | Measured value |
|------|------|------|--------|
| 0x00 | `char[2]` | Magic, fixed `"CR"` (0x43 0x52) | `43 52` |
| 0x02 | `u16 LE` | Header version, measured always 0 | `00 00` |
| 0x04 | `u32 LE` | Entry count | `05 00 00 00` = 5 |
| 0x08 | `byte[24]` | Reserved area, measured all 0 | 24 × `00` |

> Note: `"CR"` most likely stands for **C**ontainer **R**esource. The header version field exists but is always 0;
> whether it will be used in future versions is unknown - when unpacking, keep the original value so the package can be reproduced.

---

## 3. Entry Table (16 bytes per entry, little endian)

| Offset | Type | Meaning |
|------|------|------|
| +0x0 | `u32 LE` | **FNV-1a(file name)** - the index key |
| +0x4 | `u32 LE` | Absolute offset of the data in the file |
| +0x8 | `u32 LE` | Data length (bytes) |
| +0xC | `u32 LE` | File name length in bytes (excluding NUL) |

**The hash algorithm has been verified one by one**:

```python
def fnv1a32(data: bytes) -> int:
    h = 0x811C9DC5
    for b in data:
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h
```

Measured comparison (`bundle.pkg`, 5 entries, all matched):

| File name | Hash in table | Computed FNV-1a |
|--------|----------|-------------|
| `main/index.js` | `0x53374834` | `0x53374834` ✅ |
| `main/index.uo` | `0x571b7803` | `0x571b7803` ✅ |
| `main/qr-data.js` | `0x632fdbf6` | `0x632fdbf6` ✅ |
| `manifest.json` | `0x704e7b48` | `0x704e7b48` ✅ |
| `app.js` | `0xb4f94375` | `0xb4f94375` ✅ |

> ⚠️ This is a **name index**, not a content checksum. Changing the data does not invalidate the hash -
> that is, **the container layer has no integrity protection at all**.

---

## 4. Name area and alignment

- Names are concatenated back to back in **entry table order**, with no separators and no trailing NUL; they are split using `name_len`.
- After the name area, `0x00` padding is added up to the next 0x20 boundary, which is `data_start`.
- Each entry's data starts at its own `offset` and occupies `size` bytes; **the next entry's `offset` is
  `align_up(offset + size)`**. After the last entry, zero padding to a 0x20 boundary is added as well.

Measured chain (`bundle.pkg`, total file length 2240 = 0x8C0):

```
names:  0x70 .. 0xac   (13+13+15+13+6 = 60 = 0x3C)
pad →   data_start = 0xc0
0xc0 + 0xf0 (240)  = 0x1b0 → align → 0x1c0   ✅ entry 1 offset
0x1c0 + 0x1f6(502) = 0x3b6 → align → 0x3c0   ✅ entry 2 offset
0x3c0 + 0x2cc(716) = 0x68c → align → 0x6a0   ✅ entry 3 offset
0x6a0 + 0x4d (77)  = 0x6ed → align → 0x700   ✅ entry 4 offset
0x700 + 0x1b3(435) = 0x8b3 → align → 0x8c0   ✅ = file length
```

---

## 5. Entry order

**Not sorted**. The measured order produced by `gx build` is a by-product of the build process:

```
main/index.js → main/index.uo → main/qr-data.js → manifest.json → app.js
```

The index table order matches the physical order in the data area (offsets increase monotonically).
**For a byte-level reproduction the original order must be kept** - which is exactly why `pkg_tool.py` records the order in a `.pkg-index.json`
sidecar.

---

## 6. Encoding of the embedded `manifest.json`

The `manifest.json` inside the package is **not text JSON** but compiled binary. The measured 77-byte layout:

| Offset | Type | Meaning |
|------|------|------|
| 0x00 | `u32 LE` | Magic `0x0168B5AE` (fixed) |
| 0x04 | `u32 LE` | 0 |
| **0x08** | `u32 LE` | **`(vendorID << 16) \| productID`** ← device binding |
| 0x0C | `u32 LE` | 1 |
| from 0x10 | sequence | Several `u16 length prefix + UTF-8` strings |

The measured string sequence is: `package` → `name` → `versionName` → `""` (empty string) → several trailing fixed-size fields.

Decoded from this sample:

```
magic       0x0168b5ae
device_id   0x00000025   → vendorID=0x0000 productID=0x0025
package     com.rtos.qrwatch
name        扫码卡片
versionName 1.0.0
consumed    0x39 / 0x4d
tail        0b 00 00 00 | 01 00 00 00 | 04 00 "main" | 01 00 00 00 | 00 00 00 00
            (semantics not confirmed, kept as is)
```

### 6.1 Controlled verification of the device ID (key)

`vendorID` / `productID` come from the **device config chosen at build time** (`gx build -d <name>`),
hardcoded in `share/glyphix/devices/<name>.yml`:

```yaml
vendorID: 0x0000
productID: 0x0025     # default-watch-466x466.yml
```

Build the same app with four different configs and read the manifest's `u32@0x08`:

| Device config | vendorID in yml | productID in yml | Measured `u32@0x08` | Inference |
|----------|-----------------|------------------|-----------------|------|
| `default-watch-466x466` | 0x0000 | 0x0025 | `0x00000025` | ✅ |
| `default-watch-360x360` | 0x0000 | 0x0026 | `0x00000026` | ✅ |
| `generic-watch-466x466` | 0x0000 | 0x0000 | `0x00000000` | ✅ |
| **`oppo-rtos-watch` (self-made)** | **0x1234** | **0x5678** | **`0x12345678`** | ✅ causality confirmed |

A self-made device yml placed in the user directory is picked up by the toolchain:

```
%APPDATA%\glyphix\devices\<name>.yml     ← the device search path in the gx list path
```

**Conclusion**: to build a package for a given vendor/product, you do not need to "first capture a genuine package and backfill the ID" -
just write a device yml and any ID can be baked in. Conversely, for a captured genuine package, reading it with
`pkg_tool.py manifest` tells you which device it is bound to.

> Still note: **knowing the ID ≠ being able to install**. Whether the watch firmware really validates this ID pair,
> and what a validation failure looks like (`InvalidDevice`? silent rejection?) - this step must be verified on a real device.

---

## 7. Security summary

| Dimension | Conclusion | Basis |
|------|------|------|
| Signature | **None** | The container has no signature field; the index hash still holds after tampering with data |
| Content checksum | **None** | The index hash is computed over the **file name**, unrelated to content |
| Encryption | **None** | The data area is plaintext, JS source can be read directly |
| Compression | **None** | `main/qr-data.js` is stored as raw text |
| Device binding | **Yes, but only declarative** | manifest `u32@0x08`; validation is on the firmware side, not verified |

This is consistent with the official docs: the framework layer `installPackage()` does no signature verification, and the vendor adds its own signature policy on top.

---

## 8. Reproduction commands

```bash
# 1. Install the toolchain (Windows)
npm install glyphix-cli

# 2. Create a project + build the package
gx new -t simple com.example.app
cd com.example.app
gx build -d default-watch-466x466
#   → .glyphix-work/dist/<device>/com.example.app/bundle.pkg

# 3. Verify with this tool
python pkg_tool.py info      bundle.pkg
python pkg_tool.py manifest  bundle.pkg
python pkg_tool.py extract   bundle.pkg ./out
python pkg_tool.py verify    bundle.pkg      # must print "字节级一致: YES" (byte-level identical: YES)
```

---

## 9. Verified / unconfirmed

**Verified byte by byte**
- Header structure, entry table field semantics, FNV-1a index hash, name area, 0x20 alignment rule
- The `data_start` derivation formula, padding after the last entry, total file length
- `manifest` magic, `device_id = (vendorID<<16)|productID` (controlled experiment)
- The unpacked result is **fully identical** to the official `gx pack -x` output
- Unpack → repack **round trip is byte-level identical**

**Unconfirmed (do not use as conclusions)**
- Semantics of the manifest fields after `0x39` in the tail (`0b 00 00 00`, `01 00 00 00`, the `01` after `"main"`, etc.)
- When the header version field will be enabled
- Whether the entry order is stable across all `gx` versions/configs (this tool avoids relying on that assumption by using a sidecar)
- The firmware's actual validation behavior for `vendorID/productID`

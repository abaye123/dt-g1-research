Source repository: https://github.com/purrrock/ATS3085S_firmware_packer (MIT). This is an unofficial translation.

## 3. Architecture and specification of the Actions AOTA protocol

This document describes the results of reverse engineering the network layer of the proprietary **Actions Semiconductor OTA (AOTA)** protocol used in smartwatches based on ATS3085 / ATS3085S chipsets (including DT NO.1).

---

### 3.1. Bluetooth GATT topology

Communication goes through one fixed service and two main characteristics:

| Parameter | UUID / Value | Purpose |
| :--- | :--- | :--- |
| **GATT Service / Data Characteristic** | `e49a25e0-f69a-11e8-8eb2-f2801f1b9fd1` | Main channel for control and payload transfer (AOTA Stream) |
| **Control / Keep-Alive Characteristic** | `26078ae1-dfe6-4657-9427-178458b911a1` | Incremental session ping channel (Heartbeat) |

---

### 3.2. Structure of control commands (Handshake)

All control commands are written to the `e49a25e0-...` characteristic with response acknowledgement enabled (`Write With Response`).

The control frame header has the structure:
`[CMD_ID: 1B] [SUB_CMD: 1B] [FLAGS: 1B] [LENGTH: 2B Little-Endian] [PAYLOAD]`

#### Session sequence:

1. **`CMD_OTA_REQUEST` (`0x09 0x01`)**
   * **Binary frame:** `09 01 80 43 00 01 20 00 31 2e 30 30 5f 26 02 28 31 37 30 33 ...`
   * **Description:** Request to initialize OTA. Transmits the hardware platform ID (`A5S10GLY`), the version of the current firmware and the partition identifier structures. The microcontroller's bootloader validates whether the container is applicable to this device.

2. **`CMD_OTA_START` (`0x09 0x02`)**
   * **Binary frame:** `09 02 80 00 00`
   * **Description:** Signal to put the watch into firmware receive mode. The bootloader prepares the ROM buffers and prepares the internal Flash memory for block-by-block erase/write.

3. **`CMD_OTA_SET_PARAMS` (`0x09 0x09`)**
   * **Binary frame:** `09 09 80 04 00 01 01 00 01`
   * **Description:** Configuration of transfer parameters (window size, acknowledgement mode, MTU).

4. **`CMD_OTA_END` (`0x09 0x06`)**
   * **Binary frame:** `09 06 80 00 00`
   * **Description:** End of transfer. Upon receiving this command the bootloader performs a final integrity check of the written sectors, updates the interrupt vectors and initiates a software reset of the MCU (System Reset).

---

### 3.3. Block pagination and data packet structure (Data Stream)

The physical firmware binary is transferred via sub-command **`0x0B`** using the mode without acknowledgement at the GATT level (`Write Without Response`).

#### SPI Flash page architecture (1 KB Align)
The ATS3085S bootloader writes physically to the external SPI Flash in blocks of strictly **1024 bytes (1 KB)**. The AOTA protocol is tied to this hardware feature:

1. The source binary file is divided into logical pages of 1024 bytes.
2. Each 1 KB page is cut into BLE chunks with a maximum of up to **230 bytes of payload**.
3. The Sequence ID counter is reset to zero at the start of each 1 KB page.

A typical 1 KB page is transmitted in **5 BLE packets**:
* **Chunk 0:** 230 bytes of data (`Sequence ID = 0x00`)
* **Chunk 1:** 230 bytes of data (`Sequence ID = 0x01`)
* **Chunk 2:** 230 bytes of data (`Sequence ID = 0x02`)
* **Chunk 3:** 230 bytes of data (`Sequence ID = 0x03`)
* **Chunk 4:** 104 bytes of data (`Sequence ID = 0x04`) - *the remainder up to 1024 bytes*.

#### Data frame structure (Sub-command 0x0B)

Frame length: 10 bytes of header/control + Payload.

```text
+----------+----------+-------+---------------+--------+------------------+-------------------+
| CMD ID   | SUB CMD  | FLAGS | PAYLOAD LEN   | SEQ ID | CHUNK CRC32      | BINARY DATA       |
| (1 byte) | (1 byte) | (1 B) | (2 bytes LE)  | (1 B)  | (4 bytes LE)     | (Up to 230 bytes) |
+----------+----------+-------+---------------+--------+------------------+-------------------+
|  0x09    |  0x0B    | 0x80  | Payload+5 len | 0x00.. | Standard CRC32   | Raw bytes         |
+----------+----------+-------+---------------+--------+------------------+-------------------+
```

---

### 3.4. Checksum calculation (Checksum)

Each payload chunk is protected by its own checksum:
* **Algorithm:** Standard 32-bit CRC (IEEE 802.3 / zlib).
* **Polynomial:** `0xEDB88320` (Reverse) / `0x04C11DB7`.
* **Byte order in the packet:** Little-Endian.
* **Calculation area:** Computed strictly over the payload data array of the current chunk (`BINARY DATA`, 1 to 230 bytes). The header is not included in the CRC32 calculation.

---

### 3.5. Physical layer and flow control (Flow Control)

When transferring a binary file of ~4.2 MB (about 18,500 BLE packets) at `Write Without Response` speed:

1. **DLE (Data Length Extension):** Required for sending L2CAP packets of up to 247 bytes per connection event (Connection Event). Without DLE the OS stack cuts a 240-byte AOTA packet into 12 fragments of 20 bytes, which causes an overflow of the PC adapter's TX queue.
2. **Pacing (Packet delay):** A micro-delay of `0.005 s` (5 ms) between `write_gatt_char` calls prevents packet drops in the PC controller driver, providing a stable flashing speed of about **40-50 KB/sec** (the full flashing cycle takes ~90 seconds).

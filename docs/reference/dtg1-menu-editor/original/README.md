# DT G1 Menu Editor (Glyphix / ATS3085S)

Visual GUI editor for the native application menu configuration file (`menu_list.cfg`) of DT NO.1 G1 smartwatches and clones based on the Actions Semiconductor ATS3085S hardware platform running Glyphix OS.

> **⚠️ WARNING: RISK OF BRICKING**
> Modifying system configuration files on the hidden filesystem carries a high risk. If `menu_list.cfg` is corrupted, truncated, or references invalid GUI assets, the Glyphix OS rendering engine may trigger a hardware exception (Hard Fault / Null Pointer), resulting in an infinite bootloop. The authors are not responsible for damaged devices. Proceed at your own risk.

## Technical Context

Through reverse engineering, it was proven that the Glyphix Application Manager on this platform does not generate dynamic AppIDs for custom `.pkg` apps. Instead, it relies on a hardcoded 1600-byte whitelist (`menu_list.cfg`).

This tool allows you to safely parse, reorder, hide, and hijack native slots to launch custom `.pkg` applications (e.g., replacing an unused native app slot with a custom ID).

## File Specification (`menu_list.cfg`)

* **Size limitation:** Strictly 1600 bytes (`0x640`). Any deviation in size will crash the watch's internal parser.
* **Capacity:** 100 entries maximum.
* **Entry Size:** 16 bytes (`0x10`) per slot.
* **Byte Order:** Little Endian (`<IIII`).
* **Structure:**
  * Bytes 0-3: `uint32 AppID`
  * Bytes 4-7: `uint32 IconID` (Asset pointer)
  * Bytes 8-11: `uint32 NameID` (String pointer)
  * Bytes 12-15: `uint32 Flags` (`1` = Visible, `0` = Hidden/Ignored)

## Features

* **Safe Parsing & Validation:** Ensures the modified `menu_list.cfg` maintains the exact 1600-byte structure required by the firmware. Deleted slots are safely zero-filled and shifted to the end of the array.
* **Visual Mapping:** Translates raw `AppID` hex values to human-readable application names using a dynamically loaded `AppID_mapping.csv` database.
* **Slot Manipulation:** Move (Up/Down), Hide (toggle visibility flags), and clear application slots.
* **Hijacking Support:** Allows assigning native `AppID`s (e.g., `0xC82C`) to custom `.pkg` files (like PurrRock). Automatically injects safe `IconID` and `NameID` defaults to prevent GUI render crashes on newly added slots.

## Requirements

* Python 3.8+
* `tkinter` (Standard Python library)
* `AppID_mapping.csv` (Must be present in the executable/script directory for visual mapping to work)
* PuTTY (or any Serial Terminal)
* `ser_set_real_u_py2.exe` (Factory utility to mount the hidden system partition)

---

## Usage: How to Dump and Flash `menu_list.cfg`

To access the hidden system partition (`/1:/`) of the watch, we must use the serial communication protocol (AT Commands).

### Step 1: Mount the Hidden Partition
1. On your watch, navigate to Settings and change **USB Mode** from `Mass Storage` to `Charging mode`.
2. Connect the watch to your PC via the USB cable. Windows will recognize a new Serial COM Port (e.g., `COM3`).
3. Run `ser_set_real_u_py2.exe`. This utility will mount the watch's hidden system partition as a new logical drive on your PC.
   * *Note:* Pay attention to the console output of this program. It will print your exact COM port number and the required baud rate (usually `2000000`).
4. Open the newly mounted drive and verify if a folder named `custom` exists. If not, create it manually.
5. **Close `ser_set_real_u_py2.exe`** to release the COM port lock.

### Step 2: Extract (Dump) the Current Menu
1. Open PuTTY (or another terminal emulator).
2. Create a **Serial** connection using the COM Port and Baud Rate (`2000000`) noted earlier.
3. Open the connection and press `Enter`. The watch should respond with `OK`.
4. Send the following AT command to force the Glyphix UI to dump the current menu layout to the `custom` folder:
   ```text
   AT+WRX=saveMenu
   ```
5. The watch will generate the `menu_list.cfg` file inside the `custom` folder.
6. Close PuTTY. 
7. Relaunch `ser_set_real_u_py2.exe` to mount the drive again, navigate to the `custom` folder, and copy `menu_list.cfg` to your PC.

### Step 3: Modify with DT G1 Menu Editor
1. Run `python dtg1_menu_editor.py` (or launch the compiled `.exe`).
2. Click **Load menu_list.cfg** and select your dumped `.cfg` file.
3. Modify the required slots (Add, Edit, Move, or Toggle Visibility).
4. Click **Save menu_list.cfg**. The tool will automatically validate the array length and repack the binary safely.

### Step 4: Flash Back to the Watch
1. Ensure the watch is still connected and the system partition is mounted via `ser_set_real_u_py2.exe`.
2. Copy your modified `menu_list.cfg` back into the `custom` folder on the watch, overwriting the existing file.
3. Disconnect the watch from the USB cable.
4. **Reboot the watch.** Upon boot, the UI dispatcher will parse the new `.cfg` file and update your application menu.
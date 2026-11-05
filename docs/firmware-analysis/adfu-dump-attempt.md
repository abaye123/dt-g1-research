# ADFU firmware dump: attempt log and conclusion (2026-11-05)

Goal: read-only dump of the watch flash (build 88318) to obtain the exact firmware, since the vendor server does not provide it. A full dump was the only route toward removing the preloaded images from the firmware.

## What works
- The watch enters ADFU boot-ROM download mode with `AT+WRX=adfu` over the serial channel (Charging mode). It enumerates as USB `10d6:10d6`.
- The Actions boot ROM protocol (from sonigeez/actions-adfu, verified) has a read-only memory read command: CBW `0xCD 0x93` read-RAM(address, length), plus `0xCC` inquiry. Flash is XIP-mapped at 0x10000000, so reading it read-only is possible in principle.
- Tools prepared under `tools/adfu-dump/`: `adfu_read.py`, `adfu_dump_win.py` (sends adfu, then grabs the device over WinUSB/libusb and reads memory read-only). pyusb + libusb-package + pyserial installed in `tools/adfu-dump/pylibs`.
- A WinUSB driver for `USB\VID_10D6&PID_10D6` was pre-staged with Zadig "Device -> Create New Device" (and Zadig's cert is trusted).

## The wall (Windows)
1. The ADFU USB device stays enumerable only about 6 seconds, then the boot ROM drops USB if no host command arrives.
2. To talk to it, Windows needs WinUSB bound to the device instance. Even with the driver pre-staged, the registry showed Service empty for the device instance: Windows does not finish binding WinUSB within the 6 second window.
3. After ADFU times out, the watch does NOT return to Charging mode on its own; it drops off USB and needs a physical reconnect. So automated retry between attempts is impossible.

Net: on Windows the one-time WinUSB bind cannot be landed inside the 6 second window, and it cannot be retried automatically. Windows is blocked.

## Viable path (not done)
Native Linux (live USB or a spare machine): libusb can open the device directly from usbfs the instant it appears (no pre-bound driver needed), so a single self-contained script can send `AT+WRX=adfu` over the serial port and grab the device within milliseconds, beating the 6 second fuse. WSL does not help, because usbipd still needs a Windows-side bind that hits the same race.

## Even with a dump
Removing the preloaded images needs to modify and reflash firmware. The only software flash path (ADFU flash) erases flash, and there is no 88318 recovery image, so a failed flash would brick the watch. So a dump would be for research/archive, not a safe route to removing the images.

## Commands never to send (from the firmware analysis)
partUpan, mergeUpan, testWrite, testReplaceData, delClock, clearInfo, ota, ramdump, adfu-flash with erase. Reads only.

# DT G1 firmware: debug shell command table

Source: reference firmware 88265 (C175G), file `app.bin`, analyzed as data only. Never flashed. Values may differ on build 88318.

Load base: 0x10000000 (confirmed by 8069 string-pointer matches). Virtual address = file offset + 0x10000000.

There are two command groups:

1. The outer `AT+WRX=...` table (strings near file offset 0x30bf00-0x30c400): always, realUpan, hideUpan, partUpan, mergeUpan, mass, reboot, adfu, jtag, dump, coreDump, showlog, hidelog, saveMenu, clearInfo, nvram, getNvram, screenShot, setLocation, gpsCWTest and more. `AT+WRX=dump` and `AT+WRX=coreDump` live here. The outer parser strips `AT+WRX=` and dispatches.

2. The inner shell table at file offset 0x28eeac, 31 entries, each 20 bytes: {name ptr, help ptr, 0, handler ptr, 0}. Full map below. This table contains `memDump` ("cust memory dump"), not `dump`/`coreDump`.

Observed on the real watch: sending `AT+WRX=dump` returned no serial data and switched the watch to USB mass-storage mode, with no new file on the user partition. Inconclusive until the handler disassembly is done.

## Inner shell table (handlers are Thumb, so the real address is the value with bit 0 cleared)

| name | help text | handler vaddr | file offset | note |
|---|---|---|---|---|
| mass | enter usb mass mode | 0x102169c3 | 0x2169c3 | switches to mass storage |
| clockTest | enter usb clock test | 0x100ab6e9 | 0xab6e9 | |
| bright | set lcd brightness | 0x100abe2d | 0xabe2d | |
| showFlash | show real flash | 0x102169a1 | 0x2169a1 | read, verify |
| showLog | show log | 0x1021697f | 0x21697f | |
| partUpan | part flash | 0x100abb55 | 0xabb55 | RISK, partition |
| mergeUpan | merge flash | 0x100abadd | 0xabadd | RISK, partition |
| reboot | reboot device | 0x10216941 | 0x216941 | reboots |
| delClock | delete clock | 0x100abac9 | 0xabac9 | RISK, deletes |
| showClock | show all clock | 0x100ab871 | 0xab871 | |
| testWrite | test write file | 0x102169e5 | 0x2169e5 | RISK, writes |
| testRead | test read file | 0x100ab9a5 | 0xab9a5 | |
| testReplaceData | test replace data | 0x100aba2d | 0xaba2d | RISK, writes |
| gpio_get | get gpio status | 0x100ab911 | 0xab911 | |
| pbap | get pbap | 0x100abde5 | 0xabde5 | |
| ota | ota test | 0x102169e9 | 0x2169e9 | RISK |
| send_call | send call cmd | 0x100abdc5 | 0xabdc5 | |
| wakeLock | get wake lock count | 0x100ab979 | 0xab979 | |
| setAppTest | set app test item | 0x100abc91 | 0xabc91 | |
| sleepData | test sleep data | 0x10216965 | 0x216965 | |
| switchLang | switch lang idx+1 | 0x102169dd | 0x2169dd | |
| memDump | cust memory dump | 0x10216937 | 0x216937 | DUMP, under analysis |
| a2dp | handle a2dp con or dis | 0x102169e1 | 0x2169e1 | |
| uiEffect | handle ui effect | 0x1021694f | 0x21694f | |
| screenShot | handle screen shot | 0x100ab6fd | 0xab6fd | |
| mpu | handle mpu set | 0x100abcbd | 0xabcbd | |
| quart | quart test | 0x10216927 | 0x216927 | |
| memEnable | mem enable | 0x100abc41 | 0xabc41 | |
| clearInfo | clear custom info | 0x1021692b | 0x21692b | RISK, clears |
| saveMenu | save menu | 0x100ab8ed | 0xab8ed | known safe, writes menu_list.cfg |
| enterSleep | fast enter sleep mode | 0x100ab8b9 | 0xab8b9 | |

## Do not send without disassembly
partUpan, mergeUpan ("part flash" / "merge flash"), testWrite, testReplaceData, delClock, clearInfo, ota, adfu, jtag. These names and help texts point to writing flash, repartitioning, or erasing.

A deeper per-handler disassembly (what memDump, dump, coreDump actually read and where output goes) is in `dump-commands-analysis.md`.

## Real-watch test result (2026-11-05)

Sent over the AT+WRX serial channel on the actual watch (build 88318):
- `AT+WRX=dumpbuf 0x10000000 0x1000 /0:/fwtest.bin` -> no serial reply, no file on D:, watch re-enumerated as USB mass storage.
- `AT+WRX=dump` earlier -> same behavior.

Conclusion: the `dbg` command group (which holds `dumpbuf`, `fread spi_flash`) is NOT reachable through the AT+WRX channel. That channel reaches only the `xky` group (where `saveMenu`, `mass`, `realUpan`, `showlog` live). An AT+WRX command the channel does not recognize drops the watch back to mass-storage mode and does nothing. So firmware dumping through this serial path does not work with the current framing. No harm done to the watch.

"""
One-shot ADFU dump for Windows that beats the ~6 second ADFU USB timeout.

It sends AT+WRX=adfu over the watch's serial port, then immediately grabs the
10d6:10d6 ADFU device over WinUSB and sends an inquiry to keep it alive, then
reads memory read-only (boot ROM 0xCD 0x93). It NEVER writes or erases.

Prerequisite: WinUSB must be bound (staged) for USB\\VID_10D6&PID_10D6, so Windows
auto-binds it the instant the device appears. Stage it once with Zadig.

Usage:
  python -I adfu_dump_win.py probe 0x10000000          # grab + read 256 bytes, hexdump
  python -I adfu_dump_win.py dump 0x10000000 0x400000 flash.bin   # grab + dump to file
"""
import sys
import os
import time
import struct

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "pylibs"))
import serial  # noqa: E402
import serial.tools.list_ports  # noqa: E402
import libusb_package  # noqa: E402

VID = PID = 0x10D6
EP_OUT, EP_IN = 0x02, 0x81
ADFU_SUFFIX = bytes([0x00, 0x64, 0x00, 0x61])


def find_serial():
    for p in serial.tools.list_ports.comports():
        hwid = (p.hwid or "").upper().replace(":", "").replace("&", "").replace("_", "")
        # matches "VID_10D6&PID_B00A", "VID:PID=10D6:B00A", etc.
        if "10D6" in hwid and "B00A" in hwid:
            return p.device
    return None


def send_adfu():
    port = find_serial()
    if not port:
        raise SystemExit("No watch serial port (VID_10D6 PID_B00A). Set USB mode to Charging mode.")
    s = serial.Serial(port, 2000000, timeout=0.4, write_timeout=0.4)
    try:
        s.dtr = True
        s.rts = True
        s.write(b"AT+WRX=adfu" + ADFU_SUFFIX)
        s.flush()
    finally:
        s.close()
    print("sent adfu on", port)


def cbw(tag, data_len, direction_in, cb):
    cb = bytes(cb).ljust(16, b"\0")
    return b"USBC" + struct.pack("<IIBBB", tag, data_len, 0x80 if direction_in else 0, 0, 16) + cb


def parse_csw(raw):
    if len(raw) != 13 or raw[:4] != b"USBS":
        raise IOError("bad CSW: " + bytes(raw).hex())
    return raw[12]


class Adfu:
    def __init__(self, dev):
        self.d = dev
        self.tag = 1
        try:
            dev.set_configuration()
        except Exception:
            pass

    def _n(self):
        self.tag += 1
        return self.tag

    def w(self, data):
        self.d.write(EP_OUT, data, timeout=5000)

    def r(self, n):
        return bytes(self.d.read(EP_IN, n, timeout=5000))

    def inquiry(self, length=11):
        cb = bytearray(16)
        cb[0] = 0xCC
        struct.pack_into("<H", cb, 7, length)
        self.w(cbw(self._n(), length, True, cb))
        data = self.r(length)
        st = parse_csw(self.r(13))
        return data, st

    def read_ram(self, address, length, chunk=4096):
        out = bytearray()
        for off in range(0, length, chunk):
            n = min(chunk, length - off)
            cb = bytearray(16)
            cb[0], cb[1] = 0xCD, 0x93
            struct.pack_into("<II", cb, 5, n, address + off)
            self.w(cbw(self._n(), n, True, cb))
            out += self.r(n)
            st = parse_csw(self.r(13))
            if st != 0:
                raise IOError("read 0x%08x failed, CSW %d" % (address + off, st))
            if length > 0x20000 and off % 0x20000 == 0:
                print("  %d / %d KiB" % (off // 1024, length // 1024))
        return bytes(out)


def grab_once(timeout_s=10.0):
    """Tight loop: the instant the ADFU device appears with WinUSB, open it and keep it alive."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        dev = libusb_package.find(idVendor=VID, idProduct=PID)
        if dev is not None:
            a = Adfu(dev)
            data, st = a.inquiry()
            print("grabbed ADFU; inquiry:", data.hex(" "), "status", st)
            return a
        time.sleep(0.02)
    return None


def wait_serial(timeout_s=25.0):
    """Wait until the watch is back in Charging mode (serial present)."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if find_serial():
            return True
        time.sleep(0.5)
    return False


def grab(attempts=8):
    """Retry: send adfu and try to grab; if the bind misses the 6s window, wait for the
    watch to return to Charging mode and retry. The pre-staged WinUSB may bind on some tries."""
    for i in range(attempts):
        if not find_serial():
            print("  [%d] waiting for Charging mode..." % (i + 1))
            if not wait_serial():
                raise SystemExit("Watch not in Charging mode and did not return. Reconnect and set Charging mode.")
        print("  [%d] sending adfu + grabbing..." % (i + 1))
        try:
            send_adfu()
        except Exception as e:
            print("  serial send failed (%s), retrying" % e)
            time.sleep(2)
            continue
        a = grab_once(timeout_s=10.0)
        if a is not None:
            print("  SUCCESS on attempt %d" % (i + 1))
            return a
        time.sleep(1.5)
    raise SystemExit("ADFU grab failed after %d attempts. WinUSB is not binding within the 6s window." % attempts)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    cmd = sys.argv[1]
    a = grab()
    if cmd == "probe":
        addr = int(sys.argv[2], 0)
        data = a.read_ram(addr, 256)
        print("read 0x%08x:" % addr)
        for i in range(0, len(data), 16):
            row = data[i:i + 16]
            print("%08x  %-47s  %s" % (addr + i, row.hex(" "),
                  "".join(chr(c) if 32 <= c < 127 else "." for c in row)))
    elif cmd == "dump":
        addr = int(sys.argv[2], 0)
        length = int(sys.argv[3], 0)
        out = sys.argv[4]
        t = time.time()
        data = a.read_ram(addr, length)
        with open(out, "wb") as f:
            f.write(data)
        print("dumped 0x%x bytes from 0x%08x to %s in %.1fs" % (length, addr, out, time.time() - t))
        print("head:", data[:16].hex(" "), "ascii:", "".join(chr(c) if 32 <= c < 127 else "." for c in data[:16]))


if __name__ == "__main__":
    main()

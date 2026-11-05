"""
Read-only ADFU memory reader for an Actions ATS3085S in boot-ROM download mode (10d6:10d6).

It uses ONLY the boot ROM inquiry (0xCC) and read-RAM (0xCD 0x93) commands. It never
sends write (0x13), run (0x20), or any erase/flash command. Protocol taken from
sonigeez/actions-adfu protocol.py (MIT), verified by hand.

Prereq on Windows: the 10d6:10d6 device must have the WinUSB driver bound (via Zadig).

Usage:
  python -I adfu_read.py inquiry
  python -I adfu_read.py read <hex_addr> <hex_len> <outfile>
  python -I adfu_read.py probe <hex_addr>     # read 64 bytes and hexdump, no file

Examples:
  python -I adfu_read.py read 0x10000000 0x1000 fwtest.bin
"""
import sys
import struct
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "pylibs"))
import usb.core  # noqa: E402
import usb.util  # noqa: E402
import libusb_package  # noqa: E402

VID, PID = 0x10D6, 0x10D6
EP_OUT, EP_IN = 0x02, 0x81


def cbw(tag, data_len, direction_in, cb):
    cb = bytes(cb).ljust(16, b"\0")
    return b"USBC" + struct.pack("<IIBBB", tag, data_len, 0x80 if direction_in else 0, 0, 16) + cb


def parse_csw(raw):
    if len(raw) != 13 or raw[:4] != b"USBS":
        raise IOError("bad CSW: " + raw.hex())
    return raw[12]


class Dev:
    def __init__(self):
        d = libusb_package.find(idVendor=VID, idProduct=PID)
        if d is None:
            raise SystemExit("ADFU device 10d6:10d6 not found. Is the watch in ADFU mode and WinUSB bound?")
        self.d = d
        try:
            d.set_configuration()
        except Exception:
            pass
        self.tag = 1

    def _next(self):
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
        self.w(cbw(self._next(), length, True, cb))
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
            self.w(cbw(self._next(), n, True, cb))
            out += self.r(n)
            st = parse_csw(self.r(13))
            if st != 0:
                raise IOError("read from 0x%08x failed, CSW status %d" % (address + off, st))
        return bytes(out)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    cmd = sys.argv[1]
    dev = Dev()
    if cmd == "inquiry":
        data, st = dev.inquiry()
        print("inquiry reply:", data.hex(" "), "status", st)
        print("ascii:", "".join(chr(c) if 32 <= c < 127 else "." for c in data))
    elif cmd == "probe":
        addr = int(sys.argv[2], 0)
        data = dev.read_ram(addr, 64)
        print("read 0x%08x:" % addr)
        print(data.hex(" "))
        print("ascii:", "".join(chr(c) if 32 <= c < 127 else "." for c in data))
    elif cmd == "read":
        addr = int(sys.argv[2], 0)
        length = int(sys.argv[3], 0)
        out = sys.argv[4]
        data = dev.read_ram(addr, length)
        with open(out, "wb") as f:
            f.write(data)
        print("read 0x%x bytes from 0x%08x -> %s" % (length, addr, out))
        print("head:", data[:16].hex(" "))
        print("ascii:", "".join(chr(c) if 32 <= c < 127 else "." for c in data[:16]))
    else:
        print("unknown command:", cmd)


if __name__ == "__main__":
    main()

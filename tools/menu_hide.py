"""Hide entries in a DT G1 menu_list.cfg by clearing their visibility flag. Changes only the Flags field."""
import struct, sys

SLOT = 16
SIZE = 1600

src, dst, ids = sys.argv[1], sys.argv[2], {int(a, 16) for a in sys.argv[3:]}
data = bytearray(open(src, "rb").read())
if len(data) != SIZE:
    sys.exit("expected %d bytes, got %d" % (SIZE, len(data)))
found = set()
for off in range(0, SIZE, SLOT):
    app_id = struct.unpack_from("<I", data, off)[0]
    if app_id in ids:
        struct.pack_into("<I", data, off + 12, 0)
        found.add(app_id)
        print("hidden slot %d id 0x%X" % (off // SLOT, app_id))
missing = ids - found
if missing:
    sys.exit("ids not found: %s" % sorted(hex(i) for i in missing))
open(dst, "wb").write(data)

"""List or extract Glyphix .pkg (CR) containers. Format: docs/PKG_FORMAT.md in chengchengking/oppo-watch-s-sideload."""
import glob, os, struct, sys, collections


def read_pkg(path):
    d = open(path, "rb").read()
    if d[:2] != b"CR":
        raise ValueError("not a CR container: " + path)
    n = struct.unpack("<I", d[4:8])[0]
    pos = 0x20 + n * 16
    out = []
    for i in range(n):
        _, off, size, nlen = struct.unpack("<IIII", d[0x20 + i * 16:0x30 + i * 16])
        out.append((d[pos:pos + nlen].decode("utf8", "replace"), off, size))
        pos += nlen
    return d, out


if __name__ == "__main__":
    path = sys.argv[1]
    files = sorted(glob.glob(path + "/*.pkg")) if os.path.isdir(path) else [path]
    for f in files:
        d, es = read_pkg(f)
        c = collections.Counter(os.path.splitext(e[0])[1] for e in es)
        big = sorted(((s, n) for n, o, s in es if n.endswith((".png", ".jpg", ".jpeg", ".bin", ".mp4"))), reverse=True)[:2]
        print(os.path.basename(f), len(es), dict(c.most_common(5)), big)
        if len(sys.argv) > 2:
            root = os.path.join(sys.argv[2], os.path.basename(f))
            for n, o, s in es:
                p = os.path.join(root, n.replace("/", os.sep).lstrip(os.sep) or "unnamed")
                os.makedirs(os.path.dirname(p), exist_ok=True)
                try:
                    open(p, "wb").write(d[o:o + s])
                except OSError:
                    pass

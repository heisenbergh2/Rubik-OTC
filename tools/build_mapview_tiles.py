#!/usr/bin/env python3
"""
build_mapview_tiles.py - builds a second tile set for the "Map View" mode in the Cyclopedia.

Source: the ``minimap-32-*`` and ``minimap-64-*`` files (``.bmp.lzma`` format) located
in ``assets/things/1530/``. These are tiles of Tibia's CLASSIC minimap - a flat palette
of 14 colors with RED (RGB 255,51,0) building outlines - as opposed to
``satellite-*``, which carry a "photographic" render of the world. Cipsoft ships both
sets, the OTC client currently uses only ``satellite-*``.

The output goes to ``assets/things/1530_mapview/satellite/`` and has EXACTLY the same
layout as ``assets/things/1530/satellite/`` (numbered PNGs + ``index.dat`` +
``zones/`` + ``zones.json`` + ``poi_done.png`` + ``poi_todo.png``), so the engine
(``src/client/satellitemap.cpp``) reads it without any C++ change - it is enough to
pass a different ``assetsDir``.

Running (Windows):
    py -3 tools/build_mapview_tiles.py
    py -3 tools/build_mapview_tiles.py --verify-only   # format check only

--------------------------------------------------------------------------
``index.dat`` FORMAT (reconstructed 1:1 from ``assets/things/1530/satellite/index.dat``
and verified against ``SatelliteMap::ensureIndex``, satellitemap.cpp:127-152)

  header - 28 bytes:
    0x00  4B   magic "SATL"
    0x04  u8   version (3)
    0x05  u8   ocean R      (39)
    0x06  u8   ocean G      (76)
    0x07  u8   ocean B      (165)
    0x08  u32  world minX   \
    0x0C  u32  world minY    | "world bounds (reserved)" - the engine reads
    0x10  u32  world maxX    | and discards them, they are purely informational
    0x14  u32  world maxY   /
    0x18  u32  placement count

  placement - 16 bytes, repeated ``count`` times:
    +0x00 u8   floor (0-7); the engine ignores records with floor >= 8
    +0x01 u32  x  (world, little endian; read via getU32 -> cast to int32)
    +0x05 u32  y  (world, little endian)
    +0x09 u16  w  (width in world TILES, not in pixels!)
    +0x0B u16  h  (height in world tiles)
    +0x0D u8   layer (LOD level: 2 = most detail, 0 = least)
    +0x0E u16  pngId -> file ``<dir>/satellite/<pngId>.png``

  All numbers little-endian. No padding, no footer:
  28 + 16*count == file size (original: 28 + 16*737 = 11820 B).

--------------------------------------------------------------------------
DERIVING THE PLACEMENT FROM THE FILE NAME

  Name: ``<kind>-<res>-<nx>-<ny>-<floor>-<sha256>.bmp.lzma``
  e.g.  ``minimap-32-1028-1000-07-41ac93....bmp.lzma``

    x = nx * 32          y = ny * 32          floor = <floor>

  ``res`` says how many image PIXELS fall on one world tile:
    res 16 -> 2.0 px/tile -> layer 2   (512px image = 256 tiles)
    res 32 -> 1.0 px/tile -> layer 1   (512px image = 512 tiles)
    res 64 -> 0.5 px/tile -> layer 0   (512px image = 1024 tiles)

  The BMPs do NOT always measure 512x512! Cipsoft crops tiles at the right edge
  of the world (minimap-32 has 30 pieces of 352x512, minimap-64 has 16 pieces of 176x512),
  which is why we compute the placement size from the real image dimensions:

    w = bmp_width  / px_per_tile        h = bmp_height / px_per_tile

  This formula was checked on all 737 ``satellite-*`` tiles
  against the existing ``index.dat`` - 0 mismatches (see ``--verify-only``).

--------------------------------------------------------------------------
WHY LAYER 2 GETS A COPY OF LAYER 1

  ``SatelliteMap::draw`` (satellitemap.cpp:258) picks ONE LOD level:

      targetLevel = (scale >= 0.4f) ? 2 : (scale >= 0.15f) ? 1 : 0;

  and skips (satellitemap.cpp:268) every placement with a different ``layer``. The
  ``minimap-*`` set has no counterpart of ``satellite-16``, so layer 2 - used
  at the Cyclopedia's typical zoom (scale >= 0.4) - would be EMPTY and the map would
  not draw at all. That is why every ``minimap-32`` tile is written into the
  index TWICE: once as layer 1 and once as layer 2, with the same
  coordinates and the same ``pngId`` (no file is duplicated on
  disk). Effect: at high zoom the texture is simply magnified
  (1 px per tile instead of 2), instead of disappearing.
"""

from __future__ import annotations

import argparse
import io
import lzma
import os
import re
import shutil
import struct
import sys
from collections import defaultdict

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow missing. Install: py -3 -m pip install Pillow")

# ---------------------------------------------------------------------------
# paths

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC_DIR = os.path.join(REPO, "assets", "things", "1530")
SRC_SAT = os.path.join(SRC_DIR, "satellite")
OUT_DIR = os.path.join(REPO, "assets", "things", "1530_mapview")
OUT_SAT = os.path.join(OUT_DIR, "satellite")

# auxiliary files copied 1:1 alongside the tiles
AUX_FILES = ("zones.json", "poi_done.png", "poi_todo.png")
AUX_DIRS = ("zones",)

# ---------------------------------------------------------------------------
# format constants

MAGIC = b"SATL"
VERSION = 3
OCEAN_RGB = (39, 76, 165)          # identical to the original index.dat
HEADER_SIZE = 28
RECORD_SIZE = 16
NOMINAL_TILE_PX = 512              # uncropped Cipsoft tile

# res from the file name -> (LOD layer, pixels per world tile)
RES_INFO = {16: (2, 2.0), 32: (1, 1.0), 64: (0, 0.5)}

NAME_RE = re.compile(
    r"^(?P<kind>satellite|minimap)-(?P<res>16|32|64)-"
    r"(?P<nx>\d+)-(?P<ny>\d+)-(?P<floor>\d+)-(?P<sha>[0-9a-f]+)\.bmp\.lzma$"
)

RED = (255, 51, 0)                 # building outline color in the classic palette


# ---------------------------------------------------------------------------
# LZMA


def lzma_decompress(path: str) -> bytes:
    """Unpacks Cipsoft's ``.bmp.lzma`` container.

    Layout: 32 bytes of custom header, then 13 bytes of LZMA-alone ``props`` at
    0x20 and the stream from 0x2D. The "uncompressed size" field inside props can be
    garbage (seen 0x0103 with a real size of 721018 B), so plain
    ``FORMAT_ALONE`` often returns "Corrupt input data". We try in order:
      1) props exactly as in the file,
      2) props with the size overwritten to 0xFF..FF ("unknown"),
      3) a manually assembled LZMA1 filter (lc/lp/pb + dict_size) in FORMAT_RAW.
    """
    with open(path, "rb") as fh:
        data = fh.read()
    if len(data) <= 0x2D:
        raise ValueError("file too short: %s" % path)

    props = data[0x20:0x2D]
    body = data[0x2D:]

    for header in (props, props[:5] + b"\xff" * 8):
        try:
            return lzma.decompress(header + body, format=lzma.FORMAT_ALONE)
        except lzma.LZMAError:
            pass
        except EOFError:
            pass

    # last resort: break the props down into components and go with FORMAT_RAW
    pb_byte = props[0]
    lc = pb_byte % 9
    rest = pb_byte // 9
    lp = rest % 5
    pb = rest // 5
    dict_size = struct.unpack_from("<I", props, 1)[0]
    dec = lzma.LZMADecompressor(
        format=lzma.FORMAT_RAW,
        filters=[{"id": lzma.FILTER_LZMA1, "lc": lc, "lp": lp,
                  "pb": pb, "dict_size": dict_size}],
    )
    return dec.decompress(body)


def bmp_size(blob: bytes) -> tuple[int, int]:
    """Dimensions from the BITMAPINFO/V4/V5 header (without decoding pixels)."""
    if blob[:2] != b"BM":
        raise ValueError("not a BMP")
    w, h = struct.unpack_from("<ii", blob, 18)
    return w, abs(h)


# ---------------------------------------------------------------------------
# source scanning


class Tile:
    __slots__ = ("kind", "res", "nx", "ny", "floor", "path", "w", "h", "layer",
                 "px_per_tile", "png_id")

    def __init__(self, kind, res, nx, ny, floor, path):
        self.kind = kind
        self.res = res
        self.nx = nx
        self.ny = ny
        self.floor = floor
        self.path = path
        self.layer, self.px_per_tile = RES_INFO[res]
        self.w = self.h = 0
        self.png_id = -1

    @property
    def x(self) -> int:
        return self.nx * 32

    @property
    def y(self) -> int:
        return self.ny * 32

    def sort_key(self):
        return (self.x, self.y, self.floor)

    def __repr__(self):
        return "Tile(%s-%d %d,%d f%d %dx%d)" % (
            self.kind, self.res, self.x, self.y, self.floor, self.w, self.h)


def scan(kind: str, res: int) -> list[Tile]:
    out = []
    for fn in os.listdir(SRC_DIR):
        m = NAME_RE.match(fn)
        if not m or m.group("kind") != kind or int(m.group("res")) != res:
            continue
        out.append(Tile(kind, res, int(m.group("nx")), int(m.group("ny")),
                        int(m.group("floor")), os.path.join(SRC_DIR, fn)))
    out.sort(key=Tile.sort_key)
    return out


# ---------------------------------------------------------------------------
# index.dat


def build_index(placements, bounds) -> bytes:
    """placements: list of tuples (floor, x, y, w, h, layer, png_id)."""
    buf = bytearray()
    buf += MAGIC
    buf.append(VERSION)
    buf += bytes(OCEAN_RGB)
    buf += struct.pack("<4I", *bounds)
    buf += struct.pack("<I", len(placements))
    for floor, x, y, w, h, layer, png in placements:
        buf.append(floor)
        buf += struct.pack("<ii", x, y)
        buf += struct.pack("<HH", w, h)
        buf.append(layer)
        buf += struct.pack("<H", png)
    assert len(buf) == HEADER_SIZE + RECORD_SIZE * len(placements)
    return bytes(buf)


def parse_index(blob: bytes):
    """Parser used both to check the original and to check our own output."""
    if blob[:4] != MAGIC:
        raise ValueError("bad magic: %r" % blob[:4])
    version = blob[4]
    ocean = (blob[5], blob[6], blob[7])
    bounds = struct.unpack_from("<4I", blob, 8)
    count = struct.unpack_from("<I", blob, 24)[0]
    expected = HEADER_SIZE + RECORD_SIZE * count
    if len(blob) != expected:
        raise ValueError("size %d != expected %d" % (len(blob), expected))
    recs = []
    off = HEADER_SIZE
    for _ in range(count):
        floor = blob[off]
        x, y = struct.unpack_from("<ii", blob, off + 1)
        w, h = struct.unpack_from("<HH", blob, off + 9)
        layer = blob[off + 13]
        png = struct.unpack_from("<H", blob, off + 14)[0]
        recs.append((floor, x, y, w, h, layer, png))
        off += RECORD_SIZE
    return dict(version=version, ocean=ocean, bounds=bounds, records=recs)


# ---------------------------------------------------------------------------
# verifying the formula against the original satellite/index.dat


def verify_formula() -> bool:
    """Checks (x = nx*32, y = ny*32, w = px/ppt) on all ``satellite-*``
    tiles against ``assets/things/1530/satellite/index.dat``."""
    idx_path = os.path.join(SRC_SAT, "index.dat")
    if not os.path.isfile(idx_path):
        print("  [!] missing %s - skipping formula verification" % idx_path)
        return False
    with open(idx_path, "rb") as fh:
        parsed = parse_index(fh.read())
    print("  original: version=%d ocean=%s bounds=%s placements=%d"
          % (parsed["version"], parsed["ocean"], parsed["bounds"],
             len(parsed["records"])))

    lut = {}
    for floor, x, y, w, h, layer, png in parsed["records"]:
        lut[(layer, floor, x, y)] = (w, h)

    bad = checked = 0
    for res in (16, 32, 64):
        for t in scan("satellite", res):
            blob = lzma_decompress(t.path)
            bw, bh = bmp_size(blob)
            exp_w = int(round(bw / t.px_per_tile))
            exp_h = int(round(bh / t.px_per_tile))
            key = (t.layer, t.floor, t.x, t.y)
            checked += 1
            if key not in lut:
                print("  [!] missing in original: %s" % os.path.basename(t.path))
                bad += 1
            elif lut[key] != (exp_w, exp_h):
                print("  [!] %s: computed %s != index %s"
                      % (os.path.basename(t.path), (exp_w, exp_h), lut[key]))
                bad += 1
    print("  checked %d satellite-* tiles, mismatches: %d" % (checked, bad))
    return bad == 0


def verify_grid_match() -> bool:
    """minimap-32 must lie on the same grid as satellite-32 (same for 64)."""
    ok = True
    for res in (32, 64):
        a = {(t.nx, t.ny, t.floor) for t in scan("satellite", res)}
        b = {(t.nx, t.ny, t.floor) for t in scan("minimap", res)}
        if a == b:
            print("  grid minimap-%d == satellite-%d (%d tiles) OK" % (res, res, len(a)))
        else:
            ok = False
            print("  [!] grid minimap-%d != satellite-%d: sat-only=%d mini-only=%d"
                  % (res, res, len(a - b), len(b - a)))
    return ok


# ---------------------------------------------------------------------------
# main generation


def build(force: bool = False) -> int:
    mm32 = scan("minimap", 32)
    mm64 = scan("minimap", 64)
    if not mm32:
        print("ERROR: no minimap-32-* found in %s" % SRC_DIR)
        return 1
    print("found: minimap-32 = %d, minimap-64 = %d" % (len(mm32), len(mm64)))

    if os.path.isdir(OUT_SAT) and not force:
        # the output directory is fully generated - clean up old PNGs/index
        for fn in os.listdir(OUT_SAT):
            p = os.path.join(OUT_SAT, fn)
            if os.path.isfile(p) and (fn.endswith(".png") or fn == "index.dat"):
                os.remove(p)
    os.makedirs(OUT_SAT, exist_ok=True)

    # --- PNG: global numbering, minimap-32 first (0..N), then minimap-64
    png_id = 0
    total_bytes = 0
    for group in (mm32, mm64):
        for t in group:
            blob = lzma_decompress(t.path)
            img = Image.open(io.BytesIO(blob))
            if img.mode != "RGBA":
                img = img.convert("RGBA")
            # BMP with "no data" alpha (0,0,0,0) - we keep the transparency,
            # the engine backs it with the ocean color from the index.dat header.
            t.w = int(round(img.width / t.px_per_tile))
            t.h = int(round(img.height / t.px_per_tile))
            t.png_id = png_id
            dst = os.path.join(OUT_SAT, "%d.png" % png_id)
            img.save(dst, "PNG", optimize=True)
            total_bytes += os.path.getsize(dst)
            png_id += 1
        print("  wrote %d PNG (total %d)" % (len(group), png_id))

    # --- placements
    placements = []
    # layer 2 = COPY of layer 1 (no minimap-16, see module docstring)
    for t in mm32:
        placements.append((t.floor, t.x, t.y, t.w, t.h, 2, t.png_id))
    for t in mm32:
        placements.append((t.floor, t.x, t.y, t.w, t.h, 1, t.png_id))
    for t in mm64:
        placements.append((t.floor, t.x, t.y, t.w, t.h, 0, t.png_id))

    # --- world bounds (the "reserved" field): the minimap-32 grid at nominal size
    min_x = min(t.x for t in mm32)
    min_y = min(t.y for t in mm32)
    max_x = max(t.x for t in mm32) + NOMINAL_TILE_PX
    max_y = max(t.y for t in mm32) + NOMINAL_TILE_PX
    bounds = (min_x, min_y, max_x, max_y)

    blob = build_index(placements, bounds)
    idx_path = os.path.join(OUT_SAT, "index.dat")
    with open(idx_path, "wb") as fh:
        fh.write(blob)
    total_bytes += len(blob)
    print("  index.dat: %d placements, %d B, bounds=%s"
          % (len(placements), len(blob), bounds))

    # --- auxiliary files
    for name in AUX_DIRS:
        src = os.path.join(SRC_SAT, name)
        dst = os.path.join(OUT_SAT, name)
        if os.path.isdir(src):
            if os.path.isdir(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
            n = len(os.listdir(dst))
            print("  copied directory %s/ (%d files)" % (name, n))
    for name in AUX_FILES:
        src = os.path.join(SRC_SAT, name)
        if os.path.isfile(src):
            shutil.copy2(src, os.path.join(OUT_SAT, name))
            print("  copied %s" % name)
        else:
            print("  [i] %s missing in source - skipping" % name)

    return 0


# ---------------------------------------------------------------------------
# output check


def verify_output() -> int:
    idx_path = os.path.join(OUT_SAT, "index.dat")
    if not os.path.isfile(idx_path):
        print("ERROR: missing %s" % idx_path)
        return 1
    with open(idx_path, "rb") as fh:
        parsed = parse_index(fh.read())
    recs = parsed["records"]
    by_layer = defaultdict(int)
    for r in recs:
        by_layer[r[5]] += 1
    print("  output: version=%d ocean=%s bounds=%s placements=%d"
          % (parsed["version"], parsed["ocean"], parsed["bounds"], len(recs)))
    print("  layer2=%d layer1=%d layer0=%d"
          % (by_layer[2], by_layer[1], by_layer[0]))

    ok = True
    # every pngId must exist, and its dimensions must match w/h
    px_of_layer = {2: None, 1: 1.0, 0: 0.5}   # layer2 is a copy of layer1 -> 1.0 px/tile
    for floor, x, y, w, h, layer, png in recs:
        p = os.path.join(OUT_SAT, "%d.png" % png)
        if not os.path.isfile(p):
            print("  [!] missing file %s" % p)
            ok = False
            continue
        iw, ih = Image.open(p).size
        ppt = 1.0 if layer in (1, 2) else 0.5
        if (int(round(iw / ppt)), int(round(ih / ppt))) != (w, h):
            print("  [!] %d.png %s does not match w/h %s (layer %d)"
                  % (png, (iw, ih), (w, h), layer))
            ok = False
        if not (0 <= floor <= 7):
            print("  [!] floor out of range: %d" % floor)
            ok = False

    # layer2 must be a complete copy of layer1
    l1 = sorted((r[0], r[1], r[2], r[3], r[4], r[6]) for r in recs if r[5] == 1)
    l2 = sorted((r[0], r[1], r[2], r[3], r[4], r[6]) for r in recs if r[5] == 2)
    if l1 == l2:
        print("  layer2 == layer1 (%d records) OK" % len(l1))
    else:
        print("  [!] layer2 is not a copy of layer1")
        ok = False

    # sample of red RGB(255,51,0)
    sample = pick_sample(recs)
    if sample:
        png, label = sample
        img = Image.open(os.path.join(OUT_SAT, "%d.png" % png)).convert("RGBA")
        px = img.load()
        red = 0
        for yy in range(img.height):
            for xx in range(img.width):
                if px[xx, yy][:3] == RED:
                    red += 1
        pct = 100.0 * red / (img.width * img.height)
        print("  sample %s -> %d.png: pixels RGB%s = %d (%.2f%%)"
              % (label, png, RED, red, pct))
        if red == 0:
            print("  [!] no red in the sample")
            ok = False

    files = [f for f in os.listdir(OUT_SAT) if f.endswith(".png")]
    size = sum(os.path.getsize(os.path.join(OUT_SAT, f)) for f in files)
    size += os.path.getsize(idx_path)
    print("  PNGs in directory: %d, size (PNG + index.dat): %.2f MB"
          % (len(files), size / 1048576.0))
    return 0 if ok else 1


def pick_sample(recs):
    """Tile with file-name coordinates 1028-1000, floor 07 (x=32896, y=32000)."""
    for floor, x, y, w, h, layer, png in recs:
        if layer == 1 and floor == 7 and x == 1028 * 32 and y == 1000 * 32:
            return png, "minimap-32-1028-1000-07"
    for floor, x, y, w, h, layer, png in recs:
        if layer == 1 and floor == 7:
            return png, "layer1 floor7 %d,%d" % (x, y)
    return None


# ---------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--verify-only", action="store_true",
                    help="only check the formula and the existing output, do not generate")
    ap.add_argument("--skip-verify", action="store_true",
                    help="skip the costly formula verification on satellite-* tiles")
    args = ap.parse_args()

    print("source : %s" % SRC_DIR)
    print("output : %s" % OUT_SAT)

    if not args.skip_verify:
        print("\n[1] verifying the formula against satellite/index.dat")
        verify_grid_match()
        verify_formula()

    if not args.verify_only:
        print("\n[2] generating")
        rc = build()
        if rc:
            return rc

    print("\n[3] output check")
    return verify_output()


if __name__ == "__main__":
    sys.exit(main())

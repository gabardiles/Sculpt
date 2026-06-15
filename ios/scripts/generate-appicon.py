#!/usr/bin/env python3
"""Generate the iOS app icon — a soft white heart on Sculpt's dusty-pink
gradient — with no third-party deps (pure stdlib PNG writer + supersampling).

Run: python3 ios/scripts/generate-appicon.py
Writes: ios/Sculpt/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024²)
"""
import os, zlib, struct

SIZE = 1024
SS = 2                      # supersample factor for antialiasing
N = SIZE * SS

# Brand gradient stops (top-left -> mid -> bottom-right), matching the web icon.
STOPS = [(0.00, (0xF0, 0xD6, 0xD2)),
         (0.55, (0xE8, 0xC8, 0xC4)),
         (1.00, (0xC9, 0x93, 0x8E))]


def lerp(a, b, t):
    return a + (b - a) * t


def gradient(t):
    t = max(0.0, min(1.0, t))
    for i in range(len(STOPS) - 1):
        t0, c0 = STOPS[i]
        t1, c1 = STOPS[i + 1]
        if t <= t1:
            f = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            return tuple(int(round(lerp(c0[k], c1[k], f))) for k in range(3))
    return STOPS[-1][1]


def heart_inside(nx, ny):
    # Classic implicit heart: (x^2 + y^2 - 1)^3 - x^2 y^3 <= 0
    a = nx * nx + ny * ny - 1.0
    return a * a * a - nx * nx * ny * ny * ny <= 0.0


# Render the supersampled grid, accumulate into the final 1024² buffer.
R = N * 0.33               # heart scale
cx = N * 0.5
cy = N * 0.50              # vertical centre of the heart space

# Accumulators per final pixel (sum of SS*SS subsamples).
acc = [[ [0, 0, 0] for _ in range(SIZE)] for _ in range(SIZE)]

for sy in range(N):
    ny = (cy - sy) / R     # y up
    fy = sy // SS
    for sx in range(N):
        # background gradient along the diagonal
        t = (sx + sy) / (2.0 * N)
        r, g, b = gradient(t)
        # white heart on top
        nx = (sx - cx) / R
        if heart_inside(nx, ny):
            r, g, b = 0xFB, 0xF7, 0xF6
        fx = sx // SS
        cell = acc[fy][fx]
        cell[0] += r; cell[1] += g; cell[2] += b

# Downsample (box filter) and pack rows for PNG.
div = SS * SS
raw = bytearray()
for y in range(SIZE):
    raw.append(0)          # filter type 0 (none) per scanline
    row = acc[y]
    for x in range(SIZE):
        c = row[x]
        raw.append(c[0] // div)
        raw.append(c[1] // div)
        raw.append(c[2] // div)


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))


out = (b"\x89PNG\r\n\x1a\n" +
       chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)) +
       chunk(b"IDAT", zlib.compress(bytes(raw), 9)) +
       chunk(b"IEND", b""))

dest_dir = os.path.join(os.path.dirname(__file__), "..",
                        "Sculpt/Resources/Assets.xcassets/AppIcon.appiconset")
dest_dir = os.path.normpath(dest_dir)
os.makedirs(dest_dir, exist_ok=True)
with open(os.path.join(dest_dir, "AppIcon.png"), "wb") as f:
    f.write(out)
print("Wrote", os.path.join(dest_dir, "AppIcon.png"), f"({SIZE}x{SIZE})")

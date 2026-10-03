"""Generate public synthetic PNGs for simulator Photos picker verification.

Uses only the Python standard library. Outputs are test evidence, never App assets.
"""

import argparse
from pathlib import Path
import struct
import zlib


def chunk(kind, payload):
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def write_png(path, width, height, transparent=False):
    channels = 4 if transparent else 3
    rows = bytearray()
    colors = ((220, 70, 55), (55, 150, 95), (55, 100, 205))
    for y in range(height):
        rows.append(0)
        for x in range(width):
            color = colors[min(2, x * 3 // width)]
            if x < width // 6 and y < height // 6:
                color = (245, 210, 60)
            elif x >= width * 5 // 6 and y >= height * 5 // 6:
                color = (30, 30, 30)
            rows.extend(color)
            if channels == 4:
                inside = (x - width // 2) ** 2 + (y - height // 2) ** 2 < (width // 3) ** 2
                rows.append(255 if inside else 0)
    header = struct.pack(">IIBBBBB", width, height, 8, 6 if transparent else 2, 0, 0, 0)
    content = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"sRGB", b"\x00")
    content += chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
    path.write_bytes(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for name, width, height, transparent in (
        ("stage02-portrait.png", 360, 540, False),
        ("stage02-landscape.png", 540, 360, False),
        ("stage02-transparent.png", 360, 360, True),
    ):
        path = args.output / name
        write_png(path, width, height, transparent)
        print(f"{path}: {width}x{height}, {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()

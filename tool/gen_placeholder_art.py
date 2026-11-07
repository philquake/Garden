"""One-off generator for assets/art/placeholder (PNG frames + manifest.json)."""
import colorsys
import json
import math
import struct
import zlib

D = 'assets/art/placeholder'
HUES = {'tulip': 0.97, 'sunflower': 0.13, 'lavender': 0.75, 'daisy': 0.58}
W = 128


def write_png(path, px):
    raw = b''.join(b'\0' + bytes(px[y * W * 4:(y + 1) * W * 4]) for y in range(W))

    def chunk(t, b):
        c = struct.pack('>I', len(b)) + t + b
        return c + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)

    ihdr = struct.pack('>IIBBBBB', W, W, 8, 6, 0, 0, 0)
    data = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr)
            + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
    open(path, 'wb').write(data)


def make(hue, stage, health):
    sat = {'healthy': .55, 'thirsty': .45, 'wilting': .3, 'petalLoss': .2}[health]
    val = {'healthy': .95, 'thirsty': .9, 'wilting': .8, 'petalLoss': .75}[health]
    r = 8 + stage * 11
    cy = 100 - stage * 8 if health in ('healthy', 'thirsty') else 104 - stage * 5
    rgb = [int(v * 255) for v in colorsys.hsv_to_rgb(hue, sat, val)]
    px = bytearray(W * W * 4)
    for y in range(W):
        for x in range(W):
            dd = math.hypot(x - 64, y - cy) / r
            if dd < 1:
                c, a = rgb, int(200 * (1 - dd * dd * .5))
            elif 62 <= x < 66 and cy < y < 122:
                c, a = (90, 150, 90), 180
            else:
                continue
            i = (y * W + x) * 4
            px[i:i + 4] = bytes([*c, a])
    return px


manifest = {}
for f, hue in HUES.items():
    manifest[f] = {}
    for s in range(5):
        manifest[f][str(s)] = {}
        states = ['healthy'] + (['wilting', 'petalLoss'] if s in (2, 4) else [])
        for h in states:
            name = f'{f}_{s}_{h}.png'
            write_png(f'{D}/{name}', make(hue, s, h))
            manifest[f][str(s)][h] = [f'{D}/{name}']
json.dump(manifest, open(f'{D}/manifest.json', 'w'), indent=1)

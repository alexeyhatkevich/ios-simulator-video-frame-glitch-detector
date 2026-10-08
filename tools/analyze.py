#!/usr/bin/env python3
"""Frame-by-frame glitch detectors for screen recordings (needs only Pillow).

    analyze.py flash FRAMES_DIR --gate X,Y,W,H --gate-color RRGGBB --roi X,Y,W,H
    analyze.py dots  FRAMES_DIR --roi X,Y,W,H

flash: while the "we are on the target screen" gate is true, how long is the text
       band blank (no dark pixels)?
dots:  per frame, bounding box and fill ratio of the red "selected" blob. A circle
       fills pi/4 (~0.785) of its bounding box, a square fills ~1.0.

Exit code 1 when a glitch is found (or when the detector never saw what it expects,
which means the ROI is wrong and a "pass" would be meaningless).
"""
import argparse
import glob
import os
import sys
from dataclasses import dataclass

from PIL import Image

Roi = tuple  # (x, y, w, h) in pixels of the extracted frame


def parse_roi(text):
    x, y, w, h = (int(v) for v in text.split(","))
    return (x, y, w, h)


def parse_color(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def _pixels(img, roi):
    x, y, w, h = roi
    region = img.convert("RGB").crop((x, y, x + w, y + h))
    # getdata() is deprecated in newer Pillow in favour of get_flattened_data()
    return list(region.get_flattened_data() if hasattr(region, "get_flattened_data") else region.getdata())


# --------------------------------------------------------------------------- flash

def dark_pixels(img, roi, threshold=110):
    """Number of 'ink' pixels (luminance below threshold) in the region."""
    return sum(1 for r, g, b in _pixels(img, roi) if (r * 299 + g * 587 + b * 114) / 1000 < threshold)


def gate_open(img, roi, color, tol=24, min_fraction=0.9):
    """True when at least `min_fraction` of the region is within `tol` of `color`."""
    px = _pixels(img, roi)
    hits = sum(1 for p in px if all(abs(p[i] - color[i]) <= tol for i in range(3)))
    return hits / len(px) >= min_fraction


@dataclass
class BlankRun:
    start: int      # index of the first blank frame
    length: int     # number of consecutive blank frames

    def ms(self, fps):
        return self.length * 1000.0 / fps


def blank_runs(samples, min_ink=20):
    """samples: iterable of (gate_open: bool, ink: int) per frame.

    A run is a stretch of consecutive frames where the gate is open and the band has
    fewer than `min_ink` dark pixels. Frames with the gate closed are ignored and
    break a run, so being on another screen can never count as a flash.
    Returns (runs, frames_with_text).
    """
    runs, current, with_text = [], None, 0
    for i, (gate, ink) in enumerate(samples):
        if gate and ink < min_ink:
            if current is None:
                current = BlankRun(i, 0)
                runs.append(current)
            current.length += 1
        else:
            current = None
            if gate:
                with_text += 1
    return runs, with_text


# --------------------------------------------------------------------------- dots

@dataclass
class Blob:
    count: int
    width: int
    height: int

    @property
    def fill(self):
        return self.count / (self.width * self.height) if self.width and self.height else 0.0


def is_red(p):
    r, g, b = p
    return r > 200 and g < 80 and b < 80


def red_blob(img, roi):
    """Bounding box and pixel count of the solid red pixels in the region (None if none)."""
    x, y, w, h = roi
    px = _pixels(img, roi)
    xs, ys, n = [], [], 0
    for i, p in enumerate(px):
        if is_red(p):
            n += 1
            xs.append(i % w)
            ys.append(i // w)
    if n == 0:
        return None
    return Blob(n, max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)


def classify(blob, min_pixels=30, square_fill=0.90):
    """'none' | 'circle' | 'square'. Rounded-square morphs land in between and count as circle."""
    if blob is None or blob.count < min_pixels:
        return "none"
    return "square" if blob.fill >= square_fill else "circle"


# --------------------------------------------------------------------------- CLI

def load_frames(directory):
    paths = sorted(glob.glob(os.path.join(directory, "*.png")))
    if not paths:
        sys.exit(f"no frames in {directory}")
    return paths


def cmd_flash(args):
    roi, gate_roi, color = parse_roi(args.roi), parse_roi(args.gate), parse_color(args.gate_color)
    samples = []
    for path in load_frames(args.frames):
        img = Image.open(path)
        samples.append((gate_open(img, gate_roi, color), dark_pixels(img, roi)))
    runs, with_text = blank_runs(samples, args.min_ink)
    gated = sum(1 for g, _ in samples if g)
    print(f"frames={len(samples)} gated={gated} gated_with_text={with_text}")
    for r in runs:
        print(f"  blank run at frame {r.start}: {r.length} frames = {r.ms(args.fps):.0f} ms")
    worst = max((r.ms(args.fps) for r in runs), default=0)
    if gated == 0 or with_text == 0:
        print("INCONCLUSIVE: gate never opened or text never seen - check --gate/--roi")
        return 1
    print(f"worst blank window: {worst:.0f} ms (limit {args.max_blank_ms} ms)")
    return 1 if worst > args.max_blank_ms else 0


def cmd_dots(args):
    roi = parse_roi(args.roi)
    kinds = []
    for path in load_frames(args.frames):
        kinds.append(classify(red_blob(Image.open(path), roi)))
        if args.verbose:
            print(os.path.basename(path), kinds[-1])
    squares, circles = kinds.count("square"), kinds.count("circle")
    print(f"frames={len(kinds)} circle={circles} square={squares}")
    if circles == 0:
        print("INCONCLUSIVE: red dot never seen - check --roi")
        return 1
    return 1 if squares > args.max_square_frames else 0


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("flash")
    f.add_argument("frames")
    f.add_argument("--gate", required=True)
    f.add_argument("--gate-color", required=True)
    f.add_argument("--roi", required=True)
    f.add_argument("--fps", type=float, default=30)
    f.add_argument("--min-ink", type=int, default=20)
    f.add_argument("--max-blank-ms", type=float, default=100)
    f.set_defaults(fn=cmd_flash)
    d = sub.add_parser("dots")
    d.add_argument("frames")
    d.add_argument("--roi", required=True)
    d.add_argument("--max-square-frames", type=int, default=0)
    d.add_argument("--verbose", action="store_true")
    d.set_defaults(fn=cmd_dots)
    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())

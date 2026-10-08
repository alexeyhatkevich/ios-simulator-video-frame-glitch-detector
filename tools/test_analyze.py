"""Unit tests on synthetic frames - no simulator, no ffmpeg needed. Run: python3 -m unittest discover -s tools"""
import unittest

from PIL import Image, ImageDraw

import analyze

PURPLE = (107, 61, 240)
GATE = (200, 780, 100, 10)
BAND = (20, 100, 300, 60)
DOTS = (100, 300, 200, 40)


def frame(on_screen=True, text=True):
    img = Image.new("RGB", (402, 874), "white")
    d = ImageDraw.Draw(img)
    if on_screen:
        d.rectangle([200, 775, 400, 860], fill=PURPLE)
    if text:
        d.rectangle([100, 110, 220, 150], fill="black")   # stand-in for glyphs
    return img


def dot_frame(shape):
    img = Image.new("RGB", (402, 874), "white")
    d = ImageDraw.Draw(img)
    if shape == "circle":
        d.ellipse([150, 310, 169, 329], fill=(255, 0, 0))
    elif shape == "square":
        d.rectangle([150, 310, 169, 329], fill=(255, 0, 0))
    elif shape == "tiny":
        d.rectangle([150, 310, 152, 312], fill=(255, 0, 0))
    return img


class FlashTests(unittest.TestCase):
    def sample(self, img):
        return (analyze.gate_open(img, GATE, PURPLE), analyze.dark_pixels(img, BAND))

    def test_text_frame_has_ink(self):
        # Proves: a frame with glyphs is not counted as blank.
        self.assertGreater(analyze.dark_pixels(frame(text=True), BAND), 1000)

    def test_blank_frame_has_no_ink(self):
        # Proves: an empty band reads zero.
        self.assertEqual(analyze.dark_pixels(frame(text=False), BAND), 0)

    def test_gate_opens_only_on_target_screen(self):
        # Proves: the unique colour signature separates the target screen from others.
        self.assertTrue(analyze.gate_open(frame(on_screen=True), GATE, PURPLE))
        self.assertFalse(analyze.gate_open(frame(on_screen=False), GATE, PURPLE))

    def test_flash_is_measured_in_frames_and_ms(self):
        # Proves: 18 blank gated frames at 30 fps = 600 ms.
        seq = [frame(on_screen=False, text=False)] * 5 + [frame(text=False)] * 18 + [frame()] * 10
        runs, with_text = analyze.blank_runs([self.sample(f) for f in seq])
        self.assertEqual([(r.start, r.length) for r in runs], [(5, 18)])
        self.assertAlmostEqual(runs[0].ms(30), 600)
        self.assertEqual(with_text, 10)

    def test_blank_frames_on_another_screen_are_not_a_flash(self):
        # Proves: the gate prevents false positives (e.g. a launcher with no title text).
        seq = [frame(on_screen=False, text=False)] * 30 + [frame()] * 10
        runs, _ = analyze.blank_runs([self.sample(f) for f in seq])
        self.assertEqual(runs, [])

    def test_clean_entry_has_no_runs(self):
        # Proves: the fixed build reports nothing.
        runs, with_text = analyze.blank_runs([self.sample(f) for f in [frame()] * 20])
        self.assertEqual((runs, with_text), ([], 20))

    def test_two_entries_make_two_runs(self):
        # Proves: runs are split when text appears in between.
        seq = [frame(text=False)] * 3 + [frame()] * 2 + [frame(text=False)] * 4
        runs, _ = analyze.blank_runs([self.sample(f) for f in seq])
        self.assertEqual([r.length for r in runs], [3, 4])


class DotTests(unittest.TestCase):
    def test_circle_fill_is_about_pi_over_four(self):
        # Proves: a circle fills ~0.785 of its bounding box.
        blob = analyze.red_blob(dot_frame("circle"), DOTS)
        self.assertAlmostEqual(blob.fill, 0.785, delta=0.06)
        self.assertEqual(analyze.classify(blob), "circle")

    def test_square_fill_is_one(self):
        # Proves: a square fills its bounding box completely.
        blob = analyze.red_blob(dot_frame("square"), DOTS)
        self.assertEqual((blob.width, blob.height), (20, 20))
        self.assertEqual(blob.fill, 1.0)
        self.assertEqual(analyze.classify(blob), "square")

    def test_no_dot_and_tiny_specks_are_ignored(self):
        # Proves: empty frames and noise below min_pixels are 'none', not 'square'.
        self.assertEqual(analyze.classify(analyze.red_blob(dot_frame("none"), DOTS)), "none")
        self.assertEqual(analyze.classify(analyze.red_blob(dot_frame("tiny"), DOTS)), "none")

    def test_roi_limits_the_search(self):
        # Proves: red outside the indicator band is ignored.
        self.assertIsNone(analyze.red_blob(dot_frame("square"), (300, 300, 50, 40)))


class CliTests(unittest.TestCase):
    def test_exit_codes(self):
        # Proves: the CLI fails on a flash, passes on clean frames, and is inconclusive on an empty ROI.
        import os, tempfile
        with tempfile.TemporaryDirectory() as bad, tempfile.TemporaryDirectory() as good:
            for i, f in enumerate([frame(text=False)] * 18 + [frame()] * 5):
                f.save(os.path.join(bad, f"{i:04d}.png"))
            for i, f in enumerate([frame()] * 23):
                f.save(os.path.join(good, f"{i:04d}.png"))
            common = ["--gate", "200,780,100,10", "--gate-color", "6b3df0", "--roi", "20,100,300,60"]
            self.assertEqual(analyze.main(["flash", bad] + common), 1)
            self.assertEqual(analyze.main(["flash", good] + common), 0)
            wrong = ["--gate", "0,0,10,10", "--gate-color", "6b3df0", "--roi", "20,100,300,60"]
            self.assertEqual(analyze.main(["flash", good] + wrong), 1)


if __name__ == "__main__":
    unittest.main()

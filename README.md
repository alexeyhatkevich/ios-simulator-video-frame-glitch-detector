# Catching one-frame UI glitches by analysing a simulator recording

Some UI bugs live for one or two frames: a title that is blank for half a second when a
screen appears, a page-indicator dot that animates in as a square instead of a circle.
You cannot see them reliably by eye and a screenshot never lands on the bad frame.

This repo shows a technique that can: record the iOS Simulator to video, split it into
30 fps frames, and measure a small region of interest (ROI) in every frame with a
~150-line Python script.

## How to run

1. Open `Demo/Demo.xcodeproj` in Xcode 15+ (or `xed Demo`), pick an iPhone simulator, press Run.
   - Choose **Naive** or **Fixed** at the top.
   - **Flash** scenario: press *Run scenario*. It switches Home / Settings tabs a few times. In Naive mode the big
     "Settings" title is blank for ~0.6 s after each switch; in Fixed mode it is there at once.
   - **Dots** scenario: press *Run scenario*. The red page-indicator dot moves 1, 2, 3, 4, 0, 1, 2. In Naive mode the new dot
     briefly morphs from a square; in Fixed mode it fades in as a circle.
2. Tests: press Cmd+U in the same project, or from the terminal

   ```bash
   xcodebuild test -scheme GlitchDemoKit -destination "platform=iOS Simulator,name=iPhone 17 Pro"
   python3 -m pip install pillow
   python3 -m unittest discover -s tools -v     # analyzer tests on synthetic frames, no simulator needed
   ```
3. Alternatively open `Package.swift` for just the library and its tests.

## Record and analyse

Build and install the demo on a booted simulator, then:

```bash
tools/record.sh <udid> flash naive out      # also: flash fixed, dots naive, dots fixed
python3 tools/analyze.py flash out/flash-naive \
    --gate 230,795,140,10 --gate-color 6b3df0 --roi 20,270,362,60
python3 tools/analyze.py dots out/dots-naive --roi 100,440,200,40
```

`record.sh` launches the app with `-mode naive|fixed -scenario flash|dots -autorun 1`, runs
`xcrun simctl io <udid> recordVideo`, and extracts frames with
`ffmpeg -vf fps=30,scale=402:-2` (402 px wide = 1 px per point on iPhone 17 Pro, so ROI numbers are points).

Results on iPhone 17 Pro, iOS 27 simulator:

| scenario | naive | fixed |
| --- | --- | --- |
| flash | blank runs of 600, 600 and 633 ms, exit 1 | 0 ms, exit 0 |
| dots  | 51 square frames, exit 1 | 0 square frames, exit 0 |

### The two detectors

- **Flash**: count dark pixels in the title band. Only frames where a *gate* is open count, and the
  gate is a screen-unique colour (here the selected tab). Gating on the title text instead would
  false-positive on any other screen. A run of consecutive blank gated frames is the flash;
  its length times 33 ms is its duration.
- **Dots**: paint idle dots solid green and the selected dot solid red, then per frame compute the red
  blob's bounding box and fill ratio. A circle fills pi/4 = 0.785 of its box, a square 1.0.

### Rules that keep the result honest

- Always run a **positive control**: the detector must fail on the known-buggy build. A green result
  from a detector that was never seen red means nothing. Both detectors also exit 1 ("inconclusive")
  if they never see what they expect, e.g. a wrong ROI.
- Use a distinctive gate; wait a couple of seconds after launch before the scenario starts. A system
  "Allow Paste" alert from the simulator bridge can dim the page; the gate then stays closed and those frames are ignored.
- Simulator video is variable frame rate; `fps=30` resamples it, so "N frames" means roughly N x 33 ms.

## Why the dots glitch

The naive `PageDotsView.select` builds the new `DotView` inside `UIView.animate(withDuration:)`. The block's
duration and curve are inherited by everything configured in it, so the freshly built dot animates from its
initial state (square corners) instead of appearing in its final state. Build it outside and animate only
what you mean to animate. The unit test reads `UIView.inheritedAnimationDuration` while building the dot
to prove which side of the block it was created on. A dedicated write-up of that bug:
https://alexeyhatkevich.blogspot.com/2026/10/objective-c-views-created-inside-uiview.html

## Layout

```
Sources/GlitchDemoKit/  TitleHeaderView, PageDotsView, DotView (naive and fixed behind GlitchMode)
Tests/                  XCTest: both modes of both views
Demo/                   XcodeGen project (committed), SwiftUI-free UIKit demo
tools/record.sh         record + extract frames
tools/analyze.py        the detectors; tools/test_analyze.py tests them on synthetic frames
```

Write-up: https://alexeyhatkevich.blogspot.com

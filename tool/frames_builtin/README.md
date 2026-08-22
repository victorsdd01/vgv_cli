# Built-in device frames

Drop device-frame **PNGs with a transparent screen** here (e.g. Apple Product
Bezels from https://developer.apple.com/design/resources/#product-bezels), then
run:

```bash
dart run tool/generate_builtin_frames.dart
```

That embeds them into `lib/core/templates/builtin_frames.dart` so they ship as
built-in frames in `vgv screenshots web` (the editor auto-detects each frame's
transparent screen and composites the screenshot inside).

The file name becomes the frame's label (e.g. `iPhone 15 Pro.png` → "iPhone 15 Pro").

Attribution: bundled Apple frames are credited in `NOTICE` and shown in the
editor. Don't claim them as your own.

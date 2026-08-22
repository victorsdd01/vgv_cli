# Built-in device frames (curated)

These PNGs (device frames with a **transparent screen**) are embedded into
`lib/core/templates/builtin_frames.dart` (base64) so they ship as the built-in
frames in `vgv screenshots web`. This is a **curated subset** (~40) kept small
enough to bundle at good quality — one/two colors per popular model, portrait
first, across iPhone / iPad / Apple Watch / MacBook / iMac / Studio Display /
Apple TV.

Regenerate after adding/removing PNGs here:

```bash
dart run tool/generate_builtin_frames.dart
```

The file name becomes the frame's label (e.g. `iPhone 17 Pro - Deep Blue - Portrait.png`).
The editor auto-detects each frame's transparent screen and composites the
screenshot inside, at the store-exact size for that device.

## Why not bundle *all* of them?

The full Apple Product Bezels set is ~178 frames / ~130 MB. Embedding all of
them at full quality would exceed pub.dev's 100 MB per-version limit; downscaling
enough to fit makes the frames soft when composited at store resolution. So we
bundle a good curated set for everyone, and offer the **full library locally**:

```bash
vgv screenshots frames <folder-of-.dmg-or-.png>
```

That extracts every frame (full quality, downscaled to ≤2000px) into
`~/.vgv/frames`, which `vgv screenshots web` auto-loads — no package bloat.

## Attribution

Bundled Apple frames are credited in `NOTICE` and shown in the editor. Don't
claim them as your own.

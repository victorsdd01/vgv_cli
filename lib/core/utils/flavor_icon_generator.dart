import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import '../../domain/entities/project_config.dart';

/// Generates per-flavor app icons with a diagonal corner banner
/// (e.g. "DEV" / "STAGING") for non-production flavors. Production keeps the
/// clean default icon.
class FlavorIconGenerator {
  const FlavorIconGenerator();

  /// iOS asset-catalog name for a flavor (production keeps the default).
  static String iosAppIconName(Flavor flavor) =>
      flavor == Flavor.production ? 'AppIcon' : 'AppIcon-${flavor.flavorName}';

  /// Generates banner icons for every non-production flavor in [flavors].
  /// No-op if there is no source icon (e.g. no mobile platform).
  Future<void> generate({
    required String projectName,
    required List<Flavor> flavors,
  }) async {
    final nonProd =
        flavors.where((f) => f != Flavor.production).toList(growable: false);
    if (nonProd.isEmpty) return;

    final master = _loadMasterIcon(projectName);
    if (master == null) return;

    for (final flavor in nonProd) {
      final banner = buildBannerIcon(master, flavor);
      _writeIosIcons(projectName, flavor, banner);
      _writeAndroidIcons(projectName, flavor, banner);
    }
  }

  /// Loads the highest-resolution source icon (iOS 1024, else Android xxxhdpi).
  img.Image? _loadMasterIcon(String projectName) {
    final ios1024 = File(path.join(projectName, 'ios', 'Runner',
        'Assets.xcassets', 'AppIcon.appiconset', 'Icon-App-1024x1024@1x.png'));
    if (ios1024.existsSync()) {
      return img.decodePng(ios1024.readAsBytesSync());
    }
    final androidHi = File(path.join(projectName, 'android', 'app', 'src',
        'main', 'res', 'mipmap-xxxhdpi', 'ic_launcher.png'));
    if (androidHi.existsSync()) {
      return img.decodePng(androidHi.readAsBytesSync());
    }
    return null;
  }

  /// Writes a per-flavor `AppIcon-<flavor>.appiconset` mirroring the sizes of
  /// the default AppIcon set.
  void _writeIosIcons(String projectName, Flavor flavor, img.Image banner) {
    final baseSet = Directory(path.join(projectName, 'ios', 'Runner',
        'Assets.xcassets', 'AppIcon.appiconset'));
    final contentsFile = File(path.join(baseSet.path, 'Contents.json'));
    if (!contentsFile.existsSync()) return;

    final contentsRaw = contentsFile.readAsStringSync();
    final contents = jsonDecode(contentsRaw) as Map<String, dynamic>;
    final destDir = Directory(path.join(projectName, 'ios', 'Runner',
        'Assets.xcassets', '${iosAppIconName(flavor)}.appiconset'));
    destDir.createSync(recursive: true);

    for (final image in (contents['images'] as List)) {
      final map = image as Map<String, dynamic>;
      final filename = map['filename'] as String?;
      if (filename == null) continue;
      final sizePt = double.parse((map['size'] as String).split('x').first);
      final scale = int.parse((map['scale'] as String).replaceAll('x', ''));
      final px = (sizePt * scale).round();
      _writeResized(banner, File(path.join(destDir.path, filename)), px);
    }
    // Same filenames, so the base Contents.json applies verbatim.
    File(path.join(destDir.path, 'Contents.json')).writeAsStringSync(contentsRaw);
  }

  /// Writes per-flavor Android launcher icons into the flavor source set,
  /// which Gradle merges over `main` for that product flavor.
  void _writeAndroidIcons(String projectName, Flavor flavor, img.Image banner) {
    final mainRes =
        Directory(path.join(projectName, 'android', 'app', 'src', 'main', 'res'));
    if (!mainRes.existsSync()) return;
    for (final entry in _androidDensities.entries) {
      final file = File(path.join(projectName, 'android', 'app', 'src',
          flavor.flavorName, 'res', 'mipmap-${entry.key}', 'ic_launcher.png'));
      _writeResized(banner, file, entry.value);
    }
  }

  // Android launcher densities → pixel size (base 48dp).
  static const Map<String, int> _androidDensities = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  /// Banner color per flavor (solid, for a clear high-contrast ribbon).
  img.Color _bandColor(Flavor flavor) {
    switch (flavor) {
      case Flavor.dev:
        return img.ColorRgb8(0x43, 0xA0, 0x47); // green
      case Flavor.staging:
        return img.ColorRgb8(0xEF, 0x6C, 0x00); // amber
      case Flavor.production:
        return img.ColorRgb8(0x2E, 0x7D, 0x32); // (unused; prod = clean)
    }
  }

  /// Composites a bold diagonal bottom-right corner ribbon with the flavor
  /// label onto a square [base] icon and returns the new image.
  img.Image buildBannerIcon(img.Image base, Flavor flavor) {
    final size = base.width;
    final icon = base.clone();
    final label = flavor.flavorName.toUpperCase();

    // Build the ribbon at its FINAL pixel size so thickness and length are
    // independent (scaling a small ribbon coupled the two and either shrank
    // the text or made the band span the whole icon).
    final thickness = (size * 0.20).round();
    final length = (size * 0.72).round(); // just spans the corner (ends clipped)
    final ribbon = img.Image(width: length, height: thickness, numChannels: 4)
      ..clear(_bandColor(flavor));

    // Render the label bold on a tight canvas, then scale it to ~60% of the
    // band thickness and composite it centered on the ribbon.
    final white = img.ColorRgb8(255, 255, 255);
    final textCanvasW = (label.length * 30) + 8;
    const textCanvasH = 56;
    final textImg = img.Image(width: textCanvasW, height: textCanvasH, numChannels: 4);
    for (var ox = 0; ox <= 2; ox++) {
      for (var oy = 0; oy <= 1; oy++) {
        img.drawString(textImg, label,
            font: img.arial48, x: 4 + ox, y: 4 + oy, color: white);
      }
    }
    final targetH = (thickness * 0.6).round();
    final targetW = (textCanvasW * targetH / textCanvasH).round();
    final textScaled = img.copyResize(textImg,
        width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
    img.compositeImage(
      ribbon,
      textScaled,
      dstX: ((length - targetW) / 2).round(),
      dstY: ((thickness - targetH) / 2).round(),
    );

    // Rotate to the diagonal and center it inside the bottom-right corner so
    // the label stays fully visible; the band ends run off the edges.
    final rotated = img.copyRotate(
      ribbon,
      angle: -45,
      interpolation: img.Interpolation.linear,
    );
    final center = (size * 0.80).round();
    img.compositeImage(
      icon,
      rotated,
      dstX: center - rotated.width ~/ 2,
      dstY: center - rotated.height ~/ 2,
    );

    return icon;
  }

  /// Writes a [master] banner image resized to [pngFile] at [size] px.
  void _writeResized(img.Image master, File pngFile, int size) {
    pngFile.parent.createSync(recursive: true);
    final resized = img.copyResize(
      master,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );
    pngFile.writeAsBytesSync(img.encodePng(resized));
  }
}

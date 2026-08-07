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

  /// Banner color per flavor.
  img.Color _bandColor(Flavor flavor) {
    switch (flavor) {
      case Flavor.dev:
        return img.ColorRgba8(0xE5, 0x3E, 0x3E, 0xF2); // red
      case Flavor.staging:
        return img.ColorRgba8(0xF2, 0x9D, 0x1B, 0xF2); // amber
      case Flavor.production:
        return img.ColorRgba8(0x2E, 0x7D, 0x32, 0xF2); // (unused; prod = clean)
    }
  }

  /// Composites a diagonal bottom-left banner with the flavor label onto a
  /// square [base] icon and returns the new image.
  img.Image buildBannerIcon(img.Image base, Flavor flavor) {
    final size = base.width;
    final icon = base.clone();
    final label = flavor.flavorName.toUpperCase();

    // Build the ribbon at an internal resolution where the 48px font is
    // prominent, then scale it to the icon. Thickness is preserved by rotation.
    const bandHeight = 110;
    final textWidth = label.length * 28; // arial48 approximation
    final ribbonLen = (textWidth + 220).clamp(420, 2200).toInt();

    final ribbon = img.Image(width: ribbonLen, height: bandHeight, numChannels: 4);
    img.fillRect(
      ribbon,
      x1: 0,
      y1: 0,
      x2: ribbonLen - 1,
      y2: bandHeight - 1,
      color: _bandColor(flavor),
    );
    img.drawString(
      ribbon,
      label,
      font: img.arial48,
      x: ((ribbonLen - textWidth) / 2).round(),
      y: ((bandHeight - 48) / 2).round(),
      color: img.ColorRgb8(255, 255, 255),
    );

    // Rotate for the bottom-right corner and scale to the icon.
    final rotated = img.copyRotate(
      ribbon,
      angle: -45,
      interpolation: img.Interpolation.linear,
    );
    final scale = (size * 0.16) / bandHeight;
    final scaled = img.copyResize(
      rotated,
      width: (rotated.width * scale).round(),
      height: (rotated.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );

    // Center the band on the bottom-right corner, nudged toward the middle.
    final nudge = (size * 0.12).round();
    final dstX = size - (scaled.width ~/ 2) - nudge;
    final dstY = size - (scaled.height ~/ 2) - nudge;
    img.compositeImage(icon, scaled, dstX: dstX, dstY: dstY);

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

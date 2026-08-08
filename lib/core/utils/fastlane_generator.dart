import 'dart:io';
import 'package:path/path.dart' as path;
import '../../domain/entities/project_config.dart';

/// Scaffolds a full Fastlane setup (Gemfile + Android/iOS lanes + store
/// metadata + a fastlane-config.md guide) for mobile projects, using the
/// bundle id the user entered (production base + per-flavor suffixes).
class FastlaneGenerator {
  const FastlaneGenerator();

  Future<void> generate(ProjectConfig config) async {
    if (!config.includeFastlane || !config.usesNativeFlavors) return;

    final root = config.projectName;
    final appName = _humanize(config.projectName);
    final baseId = config.baseBundleId;

    _write(path.join(root, 'Gemfile'), _gemfile());

    if (Directory(path.join(root, 'android')).existsSync()) {
      _writeAndroid(root, config, appName, baseId);
    }
    if (Directory(path.join(root, 'ios')).existsSync()) {
      _writeIos(root, config, appName, baseId);
    }

    _write(path.join(root, 'fastlane-config.md'),
        _configMd(config, appName, baseId));
    _appendGitignore(root);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _humanize(String projectName) => path
      .basename(projectName)
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  void _write(String filePath, String content) {
    final file = File(filePath)..parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String _gemfile() => '''source "https://rubygems.org"

gem "fastlane"

plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
''';

  // ── Android ────────────────────────────────────────────────────────────

  void _writeAndroid(
    String root,
    ProjectConfig config,
    String appName,
    String baseId,
  ) {
    final fl = path.join(root, 'android', 'fastlane');
    _write(path.join(fl, 'Appfile'),
        'json_key_file("google-play-service-account.json")\n'
        'package_name("$baseId")\n');
    _write(path.join(fl, 'Pluginfile'), '# Fastlane plugins (none yet)\n');
    _write(path.join(fl, 'Fastfile'), _androidFastfile(config, baseId));

    // Store metadata + Play Store image slots per locale.
    for (final locale in const ['en-US', 'es-ES']) {
      final md = path.join(fl, 'metadata', 'android', locale);
      _write(path.join(md, 'title.txt'), '$appName\n');
      _write(path.join(md, 'short_description.txt'),
          'A Flutter app built with vgv_cli.\n');
      _write(path.join(md, 'full_description.txt'),
          'Describe your app here. This text is shown on the Google Play '
          'store listing ($locale).\n');
      _write(path.join(md, 'changelogs', 'default.txt'),
          'Initial release.\n');
      for (final dir in const [
        'phoneScreenshots',
        'sevenInchScreenshots',
        'tenInchScreenshots',
        'featureGraphic',
        'icon',
      ]) {
        Directory(path.join(md, 'images', dir)).createSync(recursive: true);
      }
      _write(path.join(md, 'images', 'README.md'),
          _imagesReadme(locale));
    }
  }

  String _androidFastfile(ProjectConfig config, String baseId) {
    final buffer = StringBuffer()
      ..writeln('default_platform(:android)')
      ..writeln()
      ..writeln('platform :android do')
      ..writeln();

    for (final flavor in config.flavors) {
      final id = flavor.bundleId(baseId);
      final name = flavor.flavorName; // dev / staging / prod
      final isProd = flavor == Flavor.production;
      final track = isProd ? 'production' : 'internal';
      buffer
        ..writeln('  desc "Deploy ${flavor.displayName} to Play Console ($track)"')
        ..writeln('  lane :deploy_$name do')
        ..writeln('    upload_to_play_store(')
        ..writeln('      track: "$track",')
        ..writeln('      package_name: "$id",')
        ..writeln('      json_key: "google-play-service-account.json",')
        ..writeln('      aab: "../build/app/outputs/bundle/${name}Release/app-$name-release.aab",')
        ..writeln('      release_status: "completed",');
      if (isProd) {
        buffer
          ..writeln('      rollout: "0.1", # 10% phased rollout')
          ..writeln('      skip_upload_metadata: false,')
          ..writeln('      skip_upload_changelogs: false,');
      } else {
        buffer
          ..writeln('      skip_upload_metadata: true,')
          ..writeln('      skip_upload_changelogs: true,');
      }
      buffer
        ..writeln('      skip_upload_images: true,')
        ..writeln('      skip_upload_screenshots: true,')
        ..writeln('      skip_upload_apk: true')
        ..writeln('    )')
        ..writeln('  end')
        ..writeln();
    }

    buffer
      ..writeln('  desc "Print the next production version+build from Play Console"')
      ..writeln('  lane :next_build_info do')
      ..writeln('    codes = google_play_track_version_codes(')
      ..writeln('      package_name: "$baseId",')
      ..writeln('      track: "production",')
      ..writeln('      json_key: "google-play-service-account.json"')
      ..writeln('    )')
      ..writeln('    UI.message("Latest production build: #{(codes.max || 0)}")')
      ..writeln('  end')
      ..writeln('end');
    return buffer.toString();
  }

  // ── iOS ──────────────────────────────────────────────────────────────────

  void _writeIos(
    String root,
    ProjectConfig config,
    String appName,
    String baseId,
  ) {
    final fl = path.join(root, 'ios', 'fastlane');
    _write(path.join(fl, 'Appfile'),
        'app_identifier("$baseId")\n'
        '# apple_id("your@appleid.com")\n'
        '# itc_team_id("")\n'
        '# team_id("")\n');
    _write(path.join(fl, 'Fastfile'), _iosFastfile(config));

    final md = path.join(fl, 'metadata', 'en-US');
    _write(path.join(md, 'name.txt'), '$appName\n');
    _write(path.join(md, 'subtitle.txt'), '\n');
    _write(path.join(md, 'description.txt'),
        'Describe your app here (App Store listing).\n');
    _write(path.join(md, 'keywords.txt'), 'flutter\n');
    _write(path.join(md, 'release_notes.txt'), 'Initial release.\n');
  }

  String _iosFastfile(ProjectConfig config) {
    // Use the production scheme for the store build by default.
    final prodScheme = config.flavors.contains(Flavor.production)
        ? Flavor.production.flavorName
        : config.flavors.first.flavorName;
    return '''default_platform(:ios)

platform :ios do
  desc "Build and upload the $prodScheme flavor to TestFlight"
  lane :beta do
    # Requires an App Store Connect API key (see fastlane-config.md).
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "$prodScheme",
      export_method: "app-store",
    )
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
''';
  }

  // ── docs + gitignore ──────────────────────────────────────────────────────

  String _imagesReadme(String locale) =>
      '''# Play Store images ($locale)

Drop your assets here so `fastlane supply` uploads them:

- `phoneScreenshots/` — phone screenshots (PNG/JPG)
- `sevenInchScreenshots/`, `tenInchScreenshots/` — tablet screenshots
- `featureGraphic/` — 1024x500 feature graphic
- `icon/` — 512x512 high-res icon

Then set `skip_upload_images`/`skip_upload_screenshots` to `false` in the
production lane of `android/fastlane/Fastfile`.
''';

  void _appendGitignore(String root) {
    final gitignore = File(path.join(root, '.gitignore'));
    const block = '''

# Fastlane / store secrets
**/google-play-service-account.json
**/*.p8
**/*.p12
**/AuthKey_*.p8
android/fastlane/report.xml
ios/fastlane/report.xml
**/fastlane/README.md
vendor/
.bundle/
''';
    if (gitignore.existsSync()) {
      final content = gitignore.readAsStringSync();
      if (!content.contains('google-play-service-account.json')) {
        gitignore.writeAsStringSync(content + block);
      }
    } else {
      gitignore.writeAsStringSync(block);
    }
  }

  String _configMd(ProjectConfig config, String appName, String baseId) {
    final flavorLines = config.flavors
        .map((f) => '- **${f.displayName}** → `${f.bundleId(baseId)}` '
            '(`fastlane android deploy_${f.flavorName}`)')
        .join('\n');
    return '''# Fastlane setup — $appName

The CLI scaffolded Fastlane for this project. Follow these steps to make it
work. Bundle IDs are the ones you entered:

$flavorLines

## 1. Prerequisites (macOS)

Fastlane runs locally via Bundler (no global install needed):

```bash
# Ruby ships with macOS. Then, from the project root:
gem install bundler
bundle install
```

Check what you have:

```bash
ruby --version      # any 3.x is fine
bundle --version    # if missing: gem install bundler
```

If `gem`/`ruby` are missing entirely (rare on macOS), install Ruby via
Homebrew:

```bash
# Only if you don't have Homebrew (needs your admin password):
/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install ruby
```

Run any lane with `bundle exec fastlane ...` (or add `bundle exec` in front of
the commands below).

## 2. Google Play (Android)

1. In Google Play Console → Setup → API access, create a **service account**
   with release permissions and download its JSON key.
2. Save it as `android/google-play-service-account.json`
   (already git-ignored — never commit it).
3. Configure your release **signing** (`android/key.properties` + keystore).
4. Build a flavor bundle, e.g. dev:
   ```bash
   flutter build appbundle --flavor dev -t lib/main_dev.dart
   ```
5. Deploy:
   ```bash
   cd android && bundle exec fastlane deploy_dev     # internal track
   cd android && bundle exec fastlane deploy_prod    # production, 10% rollout
   ```
6. Store listing text lives in `android/fastlane/metadata/android/<locale>/`;
   screenshots/feature graphic go in `.../images/` (see the README there).

## 3. App Store (iOS)

1. Create an **App Store Connect API key** (`.p8`) and note the key id + issuer.
2. Set them in `ios/fastlane/Appfile` / via env vars.
3. Set up signing (certificates & provisioning) — consider `fastlane match`.
4. Deploy to TestFlight:
   ```bash
   cd ios && bundle exec fastlane beta
   ```

## Notes
- Never commit `google-play-service-account.json`, `*.p8`, `*.p12` (git-ignored).
- The Android version+build can be bumped from the Play Console with
  `bundle exec fastlane next_build_info`.
''';
  }
}

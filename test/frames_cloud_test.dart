import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/frames_extractor.dart';

void main() {
  test('downloads in parallel, skips present files and retries', () async {
    final out = Directory.systemTemp.createTempSync('vgv_frames_');
    addTearDown(() => out.deleteSync(recursive: true));
    File(p.join(out.path, 'present.png')).writeAsBytesSync(<int>[1]);

    final files = <String>[
      'present.png',
      'flaky.png',
      'broken.png',
      for (var i = 0; i < 20; i++) 'frame_$i.png',
    ];
    var inFlight = 0;
    var maxInFlight = 0;
    var flakyCalls = 0;

    final client = MockClient((http.Request request) async {
      if (request.url.toString() == cloudFramesManifestUrl) {
        return http.Response(
          jsonEncode(<String, Object>{
            'base': 'https://cdn.test/frames/',
            'frames': <Map<String, String>>[
              for (final f in files) <String, String>{'file': f},
            ],
          }),
          200,
        );
      }
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      inFlight--;
      final name = request.url.pathSegments.last;
      if (name == 'broken.png') return http.Response('', 500);
      if (name == 'flaky.png' && ++flakyCalls < 3) return http.Response('', 503);
      return http.Response.bytes(<int>[137, 80, 78, 71], 200);
    });

    final code = await FramesExtractor(
      logger: Logger(level: Level.quiet),
      httpClient: () => client,
    ).run(<String>['--cloud', '--out', out.path]);

    expect(code, 0);
    for (final f in files.where((f) => f != 'broken.png')) {
      expect(File(p.join(out.path, f)).existsSync(), isTrue, reason: f);
    }
    expect(File(p.join(out.path, 'broken.png')).existsSync(), isFalse);
    expect(File(p.join(out.path, 'present.png')).readAsBytesSync(), <int>[1],
        reason: 'already-present frames are not re-downloaded');
    expect(flakyCalls, 3, reason: 'retried until it succeeded');
    expect(maxInFlight, greaterThan(1), reason: 'downloads run in parallel');
    expect(maxInFlight, lessThanOrEqualTo(FramesExtractor.cloudConcurrency));
  });
}

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/screenshot_web.dart';

void main() {
  test('single export goes straight into out/', () {
    expect(exportPath('out', 'poster_iphone.png', null),
        p.join('out', 'poster_iphone.png'));
  });

  test('multi-language exports go to out/<locale>/', () {
    expect(exportPath('out', 'poster_iphone.png', 'es'),
        p.join('out', 'es', 'poster_iphone.png'));
    expect(exportPath('out', 'poster_iphone.png', 'pt-BR'),
        p.join('out', 'pt-BR', 'poster_iphone.png'));
  });

  test('a locale or name cannot escape out/', () {
    expect(exportPath('out', 'x.png', '../etc'), isNull);
    expect(exportPath('out', 'x.png', 'es/../..'), isNull);
    expect(exportPath('out', 'x.png', ''), isNull);
    expect(exportPath('out', '../../x.png', null), p.join('out', 'x.png'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mazegame/src/app_update_models.dart';

void main() {
  group('extractReleaseVersionFromReleaseUrl', () {
    test('reads version tags from full GitHub release URLs', () {
      expect(
        extractReleaseVersionFromReleaseUrl(
          'https://github.com/OngrassTech/scape/releases/tag/v1.2.3',
        ),
        '1.2.3',
      );
    });

    test('reads version tags from relative redirect locations', () {
      expect(
        extractReleaseVersionFromReleaseUrl(
          '/OngrassTech/scape/releases/tag/release-2.0.1',
        ),
        '2.0.1',
      );
    });

    test('returns an empty string when no version can be derived', () {
      expect(
        extractReleaseVersionFromReleaseUrl(
          'https://github.com/OngrassTech/scape/releases/latest',
        ),
        '',
      );
    });
  });
}

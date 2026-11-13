import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's one typeface, for Korean and Japanese alike.
abstract final class AppFonts {
  /// Pretendard JP, bundled in three static weights (400, 600, 700).
  static const String family = 'PretendardJP';

  /// For any letter it lacks: the system gothic face.
  static const List<String> fallback = ['Hiragino Sans'];

  /// The SIL Open Font License text shipped with it.
  static const String licenseAsset = 'assets/fonts/OFL.txt';
}

bool _licenseRegistered = false;

/// Adds the typeface's licence to the licences page ([showLicensePage]).
/// Call once at start; later calls do nothing.
void registerFontLicense() {
  if (_licenseRegistered) return;
  _licenseRegistered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Pretendard JP',
    ], await rootBundle.loadString(AppFonts.licenseAsset));
  });
}

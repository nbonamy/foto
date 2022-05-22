import 'dart:io';
import 'package:path/path.dart' as p;

class SystemPath {
  static String? home() {
    switch (Platform.operatingSystem) {
      case 'linux':
      case 'macos':
        return Platform.environment['HOME'];
      case 'windows':
        return Platform.environment['USERPROFILE'];
      case 'android':
        // Probably want internal storage.
        return '/storage/sdcard0';
      default:
        return null;
    }
  }

  static String? pictures() {
    String? home = SystemPath.home();
    if (home == null) return null;
    return p.join(home, 'Pictures');
  }

  static String? desktop() {
    String? home = SystemPath.home();
    if (home == null) return null;
    return p.join(home, 'Desktop');
  }
}

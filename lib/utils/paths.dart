import 'dart:io';
import 'package:foto/utils/utils.dart';
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

  static String getFolderNamedAsset(String? dirpath, {bool isDrive = false}) {
    if (isDrive) {
      return 'assets/img/drive.png';
    } else if (Utils.pathTitle(dirpath) == 'Pictures') {
      return 'assets/img/pictures.png';
    } else {
      return 'assets/img/folder.png';
    }
  }
}

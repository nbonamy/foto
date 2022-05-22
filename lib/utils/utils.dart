class Utils {
  static String? pathTitle(String? path) {
    return (path == null) ? null : ((path == '/') ? '/' : path.split('/').last);
  }
}

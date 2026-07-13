import 'package:flutter/painting.dart';

import 'platform_utils.dart';

class ThumbnailCache {
  const ThumbnailCache._();

  static Future<void> clear() async {
    await PlatformUtils.clearThumbnailCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }
}

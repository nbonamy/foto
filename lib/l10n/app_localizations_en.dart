// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get menuFile => 'File';

  @override
  String get menuFileRefresh => 'Refresh';

  @override
  String get menuFileRename => 'Rename';

  @override
  String get menuClearThumbnailCache => 'Clear Thumbnail Cache';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuEditSelectAll => 'Select All';

  @override
  String get menuEditCopy => 'Copy';

  @override
  String get menuEditCopyItems => 'Copy Items';

  @override
  String get menuImageCopy => 'Copy Image';

  @override
  String get menuEditPaste => 'Paste';

  @override
  String get menuEditPasteMove => 'Paste and Move';

  @override
  String get menuEditDelete => 'Move to Trash';

  @override
  String get menuImage => 'Image';

  @override
  String get menuImageView => 'View Fullscreen';

  @override
  String get menuImageTransform => 'Transform';

  @override
  String get menuImageRotate90CW => 'Rotate 90° CW';

  @override
  String get menuImageRotate90CCW => 'Rotate 90° CCW';

  @override
  String get menuImageRotate180 => 'Rotate 180°';

  @override
  String get menuView => 'View';

  @override
  String get menuViewInspector => 'Toggle Inspector';

  @override
  String get menuViewAppearance => 'Appearance';

  @override
  String get appearanceSystem => 'System';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get menuWindow => 'Window';

  @override
  String get favorites => 'Favorites';

  @override
  String get favoritesAdd => 'Add to Favorites';

  @override
  String get favoritesRemove => 'Remove from Favorites';

  @override
  String get devices => 'Devices';

  @override
  String get edit => 'Edit';

  @override
  String edit_with(Object software) {
    return 'Edit with $software';
  }

  @override
  String get toolbarToggleSidebar => 'Toggle Sidebar';

  @override
  String get toolbarToggleFolders => 'Toggle Folders';

  @override
  String get toolbarToggleInspector => 'Toggle Inspector';

  @override
  String get sortTitle => 'Display Order';

  @override
  String get sortByDate => 'Sort by Date';

  @override
  String get sortByName => 'Sort by Name';

  @override
  String get sortCriteriaAlphabetical => 'Alphabetical';

  @override
  String get sortCriteriaChronological => 'Chronological';

  @override
  String get sortOrderReverse => 'Reverse';

  @override
  String deleteTitleSingle(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String deleteTitleMultiple(Object count) {
    return 'Are you sure you want to delete the $count selected items?';
  }

  @override
  String deleteText(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: 'This item',
    );
    return '$_temp0 will be moved to the Trash and can be recovered from there.';
  }

  @override
  String get overwriteConfirm =>
      'Destination file(s) already exists. Do you want to overwrite them?';

  @override
  String get inspectorTitle => 'Info';

  @override
  String get inspectorEmpty => 'Select one photo to see its details.';

  @override
  String get inspectorLoading => 'Loading metadata…';

  @override
  String get inspectorFileSection => 'File';

  @override
  String get inspectorCaptureSection => 'Capture';

  @override
  String get inspectorCameraSection => 'Camera';

  @override
  String get inspectorImageSection => 'Image';

  @override
  String get inspectorCaptured => 'Captured';

  @override
  String get inspectorCreated => 'Created';

  @override
  String get inspectorNoLocation => 'No location saved for this photo.';

  @override
  String get inspectorMapUnavailable => 'Map unavailable';

  @override
  String get galleryLoading => 'Loading photos…';

  @override
  String get galleryEmpty => 'No photos in this folder.';

  @override
  String get similarPhotosTitle => 'Similar Photos';

  @override
  String get similarPhotosDescription => 'Results from this folder only';

  @override
  String similarPhotosScanning(Object processed, Object total) {
    return 'Analyzing $processed of $total';
  }

  @override
  String get similarPhotosEmpty => 'No similar photos found in this folder.';

  @override
  String get similarPhotosFailed => 'Foto could not analyze this folder.';

  @override
  String get similarPhotosCancelled => 'Analysis cancelled.';

  @override
  String get similarPhotosCancel => 'Cancel Analysis';

  @override
  String get similarPhotosRetry => 'Analyze Again';

  @override
  String get similarityNearDuplicate => 'Near duplicate';

  @override
  String get similaritySimilar => 'Similar';

  @override
  String get comparePhotos => 'Compare';

  @override
  String compareSelectionCount(Object count) {
    return '$count of 4 selected';
  }

  @override
  String get exifFileName => 'Filename';

  @override
  String get exifFileSize => 'File size';

  @override
  String get exifCreationDate => 'Creation date';

  @override
  String get exifCaptureDate => 'Taken on';

  @override
  String get exifImageSize => 'Dimensions';

  @override
  String get exifOrientation => 'Orientation';

  @override
  String get exifSceneType => 'Scene Type';

  @override
  String get exifCaptureType => 'Capture Type';

  @override
  String get exifExposureMode => 'Exposure Mode';

  @override
  String get exifExposureTime => 'Exposure';

  @override
  String get exifFNumber => 'F-Number';

  @override
  String get exifFocalLength => 'Focal Length';

  @override
  String get exifISORating => 'ISO Rating';

  @override
  String get exifExposureBias => 'Exposure Bias';

  @override
  String get exifFlashMode => 'Flash';

  @override
  String get exifWhiteBalance => 'White balance';

  @override
  String get exifBrightness => 'Brightness';

  @override
  String get exifContrast => 'Contrast';

  @override
  String get exifSaturation => 'Saturation';

  @override
  String get exifSharpness => 'Sharpness';

  @override
  String get exifCameraMake => 'Camera Make';

  @override
  String get exifCameraModel => 'Camera Model';

  @override
  String get exifColorModel => 'Color Model';

  @override
  String get exifProfileName => 'Profile Name';

  @override
  String get viewerStartSlideShow => 'Start Slideshow';

  @override
  String get viewerStopSlideShow => 'Stop Slideshow';

  @override
  String get viewerFitScreen => 'Fit Screen';

  @override
  String get viewerFillScreen => 'Fill Screen';

  @override
  String get viewerZoom => 'Zoom ';

  @override
  String get viewerZoomIn => 'Zoom In';

  @override
  String get viewerZoomOut => 'Zoom Out';

  @override
  String get viewerZoom100 => 'Zoom 1:1';

  @override
  String get viewerFirstImage => 'First Image';

  @override
  String get viewerPreviousImage => 'Previous Image';

  @override
  String get viewerNextImage => 'Next Image';

  @override
  String get viewerLastImage => 'Last Image';

  @override
  String get viewerToggleInfo => 'Toggle Info Display';

  @override
  String get viewerClose => 'Close';

  @override
  String get appName => 'foto';
}

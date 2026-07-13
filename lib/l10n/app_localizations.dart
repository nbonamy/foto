import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @menuFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// No description provided for @menuFileRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get menuFileRefresh;

  /// No description provided for @menuFileRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get menuFileRename;

  /// No description provided for @menuClearThumbnailCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Thumbnail Cache'**
  String get menuClearThumbnailCache;

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuEditSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get menuEditSelectAll;

  /// No description provided for @menuEditCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get menuEditCopy;

  /// No description provided for @menuEditCopyItems.
  ///
  /// In en, this message translates to:
  /// **'Copy Items'**
  String get menuEditCopyItems;

  /// No description provided for @menuImageCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy Image'**
  String get menuImageCopy;

  /// No description provided for @menuEditPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get menuEditPaste;

  /// No description provided for @menuEditPasteMove.
  ///
  /// In en, this message translates to:
  /// **'Paste and Move'**
  String get menuEditPasteMove;

  /// No description provided for @menuEditDelete.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get menuEditDelete;

  /// No description provided for @menuImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get menuImage;

  /// No description provided for @menuImageView.
  ///
  /// In en, this message translates to:
  /// **'View Fullscreen'**
  String get menuImageView;

  /// No description provided for @menuImageTransform.
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get menuImageTransform;

  /// No description provided for @menuImageRotate90CW.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° CW'**
  String get menuImageRotate90CW;

  /// No description provided for @menuImageRotate90CCW.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° CCW'**
  String get menuImageRotate90CCW;

  /// No description provided for @menuImageRotate180.
  ///
  /// In en, this message translates to:
  /// **'Rotate 180°'**
  String get menuImageRotate180;

  /// No description provided for @menuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// No description provided for @menuViewInspector.
  ///
  /// In en, this message translates to:
  /// **'Toggle Inspector'**
  String get menuViewInspector;

  /// No description provided for @menuViewAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get menuViewAppearance;

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceSystem;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @menuWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get menuWindow;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @favoritesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get favoritesAdd;

  /// No description provided for @favoritesRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get favoritesRemove;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @edit_with.
  ///
  /// In en, this message translates to:
  /// **'Edit with {software}'**
  String edit_with(Object software);

  /// No description provided for @toolbarToggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle Sidebar'**
  String get toolbarToggleSidebar;

  /// No description provided for @toolbarToggleFolders.
  ///
  /// In en, this message translates to:
  /// **'Toggle Folders'**
  String get toolbarToggleFolders;

  /// No description provided for @toolbarToggleInspector.
  ///
  /// In en, this message translates to:
  /// **'Toggle Inspector'**
  String get toolbarToggleInspector;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Display Order'**
  String get sortTitle;

  /// No description provided for @sortByDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by Date'**
  String get sortByDate;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Sort by Name'**
  String get sortByName;

  /// No description provided for @sortCriteriaAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get sortCriteriaAlphabetical;

  /// No description provided for @sortCriteriaChronological.
  ///
  /// In en, this message translates to:
  /// **'Chronological'**
  String get sortCriteriaChronological;

  /// No description provided for @sortOrderReverse.
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get sortOrderReverse;

  /// No description provided for @deleteTitleSingle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteTitleSingle(Object name);

  /// No description provided for @deleteTitleMultiple.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the {count} selected items?'**
  String deleteTitleMultiple(Object count);

  /// No description provided for @deleteText.
  ///
  /// In en, this message translates to:
  /// **'{count,plural ,=1{This item} other{{count} items}} will be moved to the Trash and can be recovered from there.'**
  String deleteText(num count);

  /// No description provided for @overwriteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Destination file(s) already exists. Do you want to overwrite them?'**
  String get overwriteConfirm;

  /// No description provided for @inspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get inspectorTitle;

  /// No description provided for @inspectorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Select one photo to see its details.'**
  String get inspectorEmpty;

  /// No description provided for @inspectorLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading metadata…'**
  String get inspectorLoading;

  /// No description provided for @inspectorFileSection.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get inspectorFileSection;

  /// No description provided for @inspectorCaptureSection.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get inspectorCaptureSection;

  /// No description provided for @inspectorCameraSection.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get inspectorCameraSection;

  /// No description provided for @inspectorImageSection.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get inspectorImageSection;

  /// No description provided for @inspectorCaptured.
  ///
  /// In en, this message translates to:
  /// **'Captured'**
  String get inspectorCaptured;

  /// No description provided for @inspectorCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get inspectorCreated;

  /// No description provided for @inspectorNoLocation.
  ///
  /// In en, this message translates to:
  /// **'No location saved for this photo.'**
  String get inspectorNoLocation;

  /// No description provided for @inspectorMapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map unavailable'**
  String get inspectorMapUnavailable;

  /// No description provided for @galleryLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading photos…'**
  String get galleryLoading;

  /// No description provided for @galleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos in this folder.'**
  String get galleryEmpty;

  /// No description provided for @exifFileName.
  ///
  /// In en, this message translates to:
  /// **'Filename'**
  String get exifFileName;

  /// No description provided for @exifFileSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get exifFileSize;

  /// No description provided for @exifCreationDate.
  ///
  /// In en, this message translates to:
  /// **'Creation date'**
  String get exifCreationDate;

  /// No description provided for @exifCaptureDate.
  ///
  /// In en, this message translates to:
  /// **'Taken on'**
  String get exifCaptureDate;

  /// No description provided for @exifImageSize.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get exifImageSize;

  /// No description provided for @exifOrientation.
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get exifOrientation;

  /// No description provided for @exifSceneType.
  ///
  /// In en, this message translates to:
  /// **'Scene Type'**
  String get exifSceneType;

  /// No description provided for @exifCaptureType.
  ///
  /// In en, this message translates to:
  /// **'Capture Type'**
  String get exifCaptureType;

  /// No description provided for @exifExposureMode.
  ///
  /// In en, this message translates to:
  /// **'Exposure Mode'**
  String get exifExposureMode;

  /// No description provided for @exifExposureTime.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get exifExposureTime;

  /// No description provided for @exifFNumber.
  ///
  /// In en, this message translates to:
  /// **'F-Number'**
  String get exifFNumber;

  /// No description provided for @exifFocalLength.
  ///
  /// In en, this message translates to:
  /// **'Focal Length'**
  String get exifFocalLength;

  /// No description provided for @exifISORating.
  ///
  /// In en, this message translates to:
  /// **'ISO Rating'**
  String get exifISORating;

  /// No description provided for @exifExposureBias.
  ///
  /// In en, this message translates to:
  /// **'Exposure Bias'**
  String get exifExposureBias;

  /// No description provided for @exifFlashMode.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get exifFlashMode;

  /// No description provided for @exifWhiteBalance.
  ///
  /// In en, this message translates to:
  /// **'White balance'**
  String get exifWhiteBalance;

  /// No description provided for @exifBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get exifBrightness;

  /// No description provided for @exifContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get exifContrast;

  /// No description provided for @exifSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get exifSaturation;

  /// No description provided for @exifSharpness.
  ///
  /// In en, this message translates to:
  /// **'Sharpness'**
  String get exifSharpness;

  /// No description provided for @exifCameraMake.
  ///
  /// In en, this message translates to:
  /// **'Camera Make'**
  String get exifCameraMake;

  /// No description provided for @exifCameraModel.
  ///
  /// In en, this message translates to:
  /// **'Camera Model'**
  String get exifCameraModel;

  /// No description provided for @exifColorModel.
  ///
  /// In en, this message translates to:
  /// **'Color Model'**
  String get exifColorModel;

  /// No description provided for @exifProfileName.
  ///
  /// In en, this message translates to:
  /// **'Profile Name'**
  String get exifProfileName;

  /// No description provided for @viewerStartSlideShow.
  ///
  /// In en, this message translates to:
  /// **'Start Slideshow'**
  String get viewerStartSlideShow;

  /// No description provided for @viewerStopSlideShow.
  ///
  /// In en, this message translates to:
  /// **'Stop Slideshow'**
  String get viewerStopSlideShow;

  /// No description provided for @viewerFitScreen.
  ///
  /// In en, this message translates to:
  /// **'Fit Screen'**
  String get viewerFitScreen;

  /// No description provided for @viewerFillScreen.
  ///
  /// In en, this message translates to:
  /// **'Fill Screen'**
  String get viewerFillScreen;

  /// No description provided for @viewerZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom '**
  String get viewerZoom;

  /// No description provided for @viewerZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get viewerZoomIn;

  /// No description provided for @viewerZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get viewerZoomOut;

  /// No description provided for @viewerZoom100.
  ///
  /// In en, this message translates to:
  /// **'Zoom 1:1'**
  String get viewerZoom100;

  /// No description provided for @viewerFirstImage.
  ///
  /// In en, this message translates to:
  /// **'First Image'**
  String get viewerFirstImage;

  /// No description provided for @viewerPreviousImage.
  ///
  /// In en, this message translates to:
  /// **'Previous Image'**
  String get viewerPreviousImage;

  /// No description provided for @viewerNextImage.
  ///
  /// In en, this message translates to:
  /// **'Next Image'**
  String get viewerNextImage;

  /// No description provided for @viewerLastImage.
  ///
  /// In en, this message translates to:
  /// **'Last Image'**
  String get viewerLastImage;

  /// No description provided for @viewerToggleInfo.
  ///
  /// In en, this message translates to:
  /// **'Toggle Info Display'**
  String get viewerToggleInfo;

  /// No description provided for @viewerClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get viewerClose;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'foto'**
  String get appName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

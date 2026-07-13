// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get menuFile => 'Fichier';

  @override
  String get menuFileRefresh => 'Rafraîchir';

  @override
  String get menuFileRename => 'Renommer';

  @override
  String get menuEdit => 'Edition';

  @override
  String get menuEditSelectAll => 'Tout sélectionner';

  @override
  String get menuEditCopy => 'Copier';

  @override
  String get menuEditCopyItems => 'Copier les éléments';

  @override
  String get menuImageCopy => 'Copier l’image';

  @override
  String get menuEditPaste => 'Coller';

  @override
  String get menuEditPasteMove => 'Coller Déplacer';

  @override
  String get menuEditDelete => 'Déplacer dans la Corbeille';

  @override
  String get menuImage => 'Image';

  @override
  String get menuImageView => 'Visualiser en plein écran';

  @override
  String get menuImageTransform => 'Transformations';

  @override
  String get menuImageRotate90CW => 'Rotation 90° sens horaire';

  @override
  String get menuImageRotate90CCW => 'Rotation 90° sens antihoraire';

  @override
  String get menuImageRotate180 => 'Rotation 180°';

  @override
  String get menuView => 'Affichage';

  @override
  String get menuViewInspector => 'Basculer Inspecteur';

  @override
  String get menuWindow => 'Fenêtres';

  @override
  String get favorites => 'Favoris';

  @override
  String get favoritesAdd => 'Ajouter aux Favoris';

  @override
  String get favoritesRemove => 'Retirer des Favoris';

  @override
  String get devices => 'Appareils';

  @override
  String get edit => 'Editer';

  @override
  String edit_with(Object software) {
    return 'Editer avec $software';
  }

  @override
  String get toolbarToggleSidebar => 'Afficher la barre latérale';

  @override
  String get toolbarToggleFolders => 'Afficher les dossiers';

  @override
  String get toolbarToggleInspector => 'Afficher les informations';

  @override
  String get sortTitle => 'Ordre d\'affichage';

  @override
  String get sortCriteriaAlphabetical => 'Alphabétique';

  @override
  String get sortCriteriaChronological => 'Chronologique';

  @override
  String get sortOrderReverse => 'Order inversé';

  @override
  String deleteTitleSingle(Object name) {
    return 'Etes-vous sûr de vouloir supprimer \"$name\" ?';
  }

  @override
  String deleteTitleMultiple(Object count) {
    return 'Etes-vous sûr de vouloir supprimer les $count éléments sélectionnés ?';
  }

  @override
  String deleteText(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: 'Cet élément',
    );
    return '$_temp0 vont être déplacés dans la Corbeille.';
  }

  @override
  String get overwriteConfirm =>
      'Les fichiers existent déjà. Voulez-vous les remplacer ?';

  @override
  String get exifFileName => 'Nom du fichier';

  @override
  String get exifFileSize => 'Taille du fichier';

  @override
  String get exifCreationDate => 'Date de création';

  @override
  String get exifCaptureDate => 'Date de capture';

  @override
  String get exifImageSize => 'Dimensions';

  @override
  String get exifOrientation => 'Orientation';

  @override
  String get exifSceneType => 'Type de ccène';

  @override
  String get exifCaptureType => 'Type de capture';

  @override
  String get exifExposureMode => 'Mode d\'exposition';

  @override
  String get exifExposureTime => 'Exposition ';

  @override
  String get exifFNumber => 'Nombre F';

  @override
  String get exifFocalLength => 'Longueur focale';

  @override
  String get exifISORating => 'Vitesse ISO';

  @override
  String get exifExposureBias => 'Biais d\'exposition';

  @override
  String get exifFlashMode => 'Flash';

  @override
  String get exifWhiteBalance => 'Balance des blancs';

  @override
  String get exifBrightness => 'Luminosité';

  @override
  String get exifContrast => 'Contraste';

  @override
  String get exifSaturation => 'Saturation';

  @override
  String get exifSharpness => 'Netteté';

  @override
  String get exifCameraMake => 'Marque appareil';

  @override
  String get exifCameraModel => 'Modèle appareil';

  @override
  String get exifColorModel => 'Modèle couleur';

  @override
  String get exifProfileName => 'Nom profil';

  @override
  String get viewerStartSlideShow => 'Démarrer le diaporama';

  @override
  String get viewerStopSlideShow => 'Arrêter le diaporama';

  @override
  String get viewerFitScreen => 'Ajuster à l\'écran';

  @override
  String get viewerFillScreen => 'Remplir l\'écran';

  @override
  String get viewerZoom => 'Zoom';

  @override
  String get viewerZoomIn => 'Zoomer';

  @override
  String get viewerZoomOut => 'Dézoomer';

  @override
  String get viewerZoom100 => 'Zoom 1:1';

  @override
  String get viewerFirstImage => 'Première image';

  @override
  String get viewerPreviousImage => 'Image précédente';

  @override
  String get viewerNextImage => 'Image suivante';

  @override
  String get viewerLastImage => 'Dernière image';

  @override
  String get viewerToggleInfo => 'Bascule affichage info';

  @override
  String get viewerClose => 'Fermer';

  @override
  String get appName => 'foto';
}

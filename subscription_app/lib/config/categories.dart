import '../l10n/app_localizations.dart';

/// Creator categories.
///
/// The canonical [values] are stored on the backend and shared with the web
/// frontend, so they MUST stay identical across platforms. They are persisted
/// and sent to the API as-is; only the display label is localized via [label].
class Categories {
  const Categories._();

  static const values = [
    'Музыка',
    'Искусство',
    'Подкасты',
    'Игры',
    'Образование',
    'Другое',
  ];

  /// Localized display label for a stored category [value].
  /// Unknown values are returned unchanged so existing data is never hidden.
  static String label(String value) {
    switch (value) {
      case 'Музыка':
        return L10n.t('cat_music');
      case 'Искусство':
        return L10n.t('cat_art');
      case 'Подкасты':
        return L10n.t('cat_podcasts');
      case 'Игры':
        return L10n.t('cat_games');
      case 'Образование':
        return L10n.t('cat_education');
      case 'Другое':
        return L10n.t('cat_other');
      default:
        return value;
    }
  }
}

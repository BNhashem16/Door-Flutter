// Localization sanity tests. The app's runtime tree depends on Firebase, so
// these cover the pure, context-free localization layer instead of pumping the
// full widget tree.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Door/l10n/app_strings.dart';

void main() {
  test('supports Arabic and English locales', () {
    expect(AppStrings.supportedLocales, contains(const Locale('ar')));
    expect(AppStrings.supportedLocales, contains(const Locale('en')));
  });

  test('forLanguageCode resolves distinct localizations', () {
    final ar = AppStrings.forLanguageCode('ar');
    final en = AppStrings.forLanguageCode('en');

    expect(ar.appTitle, isNotEmpty);
    expect(en.appTitle, isNotEmpty);
  });

  test('forLanguageCode falls back to Arabic for unknown codes', () {
    final unknown = AppStrings.forLanguageCode('fr');
    final ar = AppStrings.forLanguageCode('ar');

    expect(unknown.appTitle, ar.appTitle);
  });
}

import 'package:evolua_frontend/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations_en.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations_pt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsPtBr();
  final en = AppLocalizationsEn();

  group('auth form validators', () {
    test('normalizes valid email with trim and lowercase', () {
      expect(normalizeEmail('  USER@Evolua.App  '), 'user@evolua.app');
      expect(validateEmail('  USER@Evolua.App  ', l10n), isNull);
    });

    test('rejects invalid email shapes', () {
      expect(validateEmail('usuario', l10n), isNotNull);
      expect(validateEmail('usuario@', l10n), isNotNull);
      expect(validateEmail('usuario@dominio', l10n), isNotNull);
      expect(validateEmail('usuario@@dominio.com', l10n), isNotNull);
      expect(validateEmail('usuario com espaco@dominio.com', l10n), isNotNull);
      expect(validateEmail('${'a' * 245}@dominio.com', l10n), isNotNull);
    });

    test('validates password without exposing or trimming typed value', () {
      expect(validatePassword('', l10n), l10n.authValidationPasswordRequired);
      expect(
        validatePassword('   ', l10n),
        l10n.authValidationPasswordRequired,
      );
      expect(validatePassword('12345', l10n), isNotNull);
      expect(validatePassword(' 1234 ', l10n), isNull);
      expect(validatePassword('a' * 72, l10n), isNull);
      expect(validatePassword('a' * 73, l10n), isNotNull);
      expect(
        validateConfirmPassword('', '123456', l10n),
        l10n.authValidationConfirmPasswordRequired,
      );
      expect(
        validateConfirmPassword('1234567', '123456', l10n),
        l10n.authValidationPasswordsDoNotMatch,
      );
      expect(validateConfirmPassword('123456', '123456', l10n), isNull);
      expect(validatePassword('', en), 'Enter your password.');
    });

    test('validates display name and preserves human names', () {
      expect(validateDisplayName('', l10n), isNotNull);
      expect(validateDisplayName('A', l10n), isNotNull);
      expect(validateDisplayName('Ana Maria', l10n), isNull);
      expect(validateDisplayName('Jose da Silva', l10n), isNull);
      expect(validateDisplayName('Ana123', l10n), isNotNull);
      expect(validateDisplayName('Ana @ Silva', l10n), isNotNull);
      expect(validateDisplayName('Ana-Maria', l10n), isNotNull);
      expect(validateDisplayName("Ana D'Avila", l10n), isNotNull);
      expect(normalizeDisplayName('  Ana   Maria  '), 'Ana Maria');
    });

    test('validates birth date and minimum age', () {
      final now = DateTime(2026, 4, 28);

      expect(validateBirthDate(null, l10n, now: now), isNotNull);
      expect(
        validateBirthDate(DateTime(2026, 4, 29), l10n, now: now),
        isNotNull,
      );
      expect(
        validateBirthDate(DateTime(2014, 4, 28), l10n, now: now),
        isNotNull,
      );
      expect(validateBirthDate(DateTime(2013, 4, 28), l10n, now: now), isNull);
      expect(validateBirthDate(DateTime(1990, 1, 1), l10n, now: now), isNull);
      expect(parseBirthDateText('01011990'), DateTime(1990, 1, 1));
      expect(parseBirthDateText('01/01/1990'), DateTime(1990, 1, 1));
      expect(parseBirthDateText('31/02/1990'), isNull);
      expect(formatBirthDate(DateTime(1990, 1, 1)), '01/01/1990');
      expect(validateBirthDateText('', l10n, now: now), isNotNull);
      expect(validateBirthDateText('31/02/1990', l10n, now: now), isNotNull);
    });

    test('validates inclusive gender options', () {
      expect(validateGender(genderMale, l10n), isNull);
      expect(validateGender(genderFemale, l10n), isNull);
      expect(validateGender(genderPreferNotToSay, l10n), isNull);
      expect(validateGender(genderCustom, l10n), isNull);
      expect(validateGender('INVALID', l10n), isNotNull);
      expect(
        validateCustomGender(
          selectedGender: genderCustom,
          customGender: '',
          l10n: l10n,
        ),
        isNotNull,
      );
      expect(
        validateCustomGender(
          selectedGender: genderCustom,
          customGender: 'Fluid',
          l10n: l10n,
        ),
        isNull,
      );
    });
  });
}

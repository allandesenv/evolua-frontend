import 'package:evolua_frontend/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth form validators', () {
    test('normalizes valid email with trim and lowercase', () {
      expect(normalizeEmail('  USER@Evolua.App  '), 'user@evolua.app');
      expect(validateEmail('  USER@Evolua.App  '), isNull);
    });

    test('rejects invalid email shapes', () {
      expect(validateEmail('usuario'), isNotNull);
      expect(validateEmail('usuario@'), isNotNull);
      expect(validateEmail('usuario@dominio'), isNotNull);
      expect(validateEmail('usuario@@dominio.com'), isNotNull);
      expect(validateEmail('usuario com espaco@dominio.com'), isNotNull);
      expect(validateEmail('${'a' * 245}@dominio.com'), isNotNull);
    });

    test('validates password without exposing or trimming typed value', () {
      expect(validatePassword(''), 'Informe sua senha.');
      expect(validatePassword('   '), 'Informe sua senha.');
      expect(validatePassword('12345'), isNotNull);
      expect(validatePassword(' 1234 '), isNull);
      expect(validatePassword('a' * 72), isNull);
      expect(validatePassword('a' * 73), isNotNull);
      expect(validateConfirmPassword('', '123456'), 'Confirme sua senha.');
      expect(
        validateConfirmPassword('1234567', '123456'),
        'As senhas não conferem.',
      );
      expect(validateConfirmPassword('123456', '123456'), isNull);
    });

    test('validates display name and preserves human names', () {
      expect(validateDisplayName(''), isNotNull);
      expect(validateDisplayName('A'), isNotNull);
      expect(validateDisplayName('Ana Maria'), isNull);
      expect(validateDisplayName('José da Silva'), isNull);
      expect(validateDisplayName('Ana123'), isNotNull);
      expect(validateDisplayName('Ana @ Silva'), isNotNull);
      expect(validateDisplayName('Ana-Maria'), isNotNull);
      expect(validateDisplayName("Ana D'Ávila"), isNotNull);
      expect(normalizeDisplayName('  Ana   Maria  '), 'Ana Maria');
    });

    test('validates birth date and minimum age', () {
      final now = DateTime(2026, 4, 28);

      expect(validateBirthDate(null, now: now), isNotNull);
      expect(validateBirthDate(DateTime(2026, 4, 29), now: now), isNotNull);
      expect(validateBirthDate(DateTime(2014, 4, 28), now: now), isNotNull);
      expect(validateBirthDate(DateTime(2013, 4, 28), now: now), isNull);
      expect(validateBirthDate(DateTime(1990, 1, 1), now: now), isNull);
      expect(parseBirthDateText('01011990'), DateTime(1990, 1, 1));
      expect(parseBirthDateText('01/01/1990'), DateTime(1990, 1, 1));
      expect(parseBirthDateText('31/02/1990'), isNull);
      expect(formatBirthDate(DateTime(1990, 1, 1)), '01/01/1990');
      expect(validateBirthDateText('', now: now), isNotNull);
      expect(validateBirthDateText('31/02/1990', now: now), isNotNull);
    });

    test('validates inclusive gender options', () {
      expect(validateGender(genderMale), isNull);
      expect(validateGender(genderFemale), isNull);
      expect(validateGender(genderPreferNotToSay), isNull);
      expect(validateGender(genderCustom), isNull);
      expect(validateGender('INVALID'), isNotNull);
      expect(
        validateCustomGender(selectedGender: genderCustom, customGender: ''),
        isNotNull,
      );
      expect(
        validateCustomGender(
          selectedGender: genderCustom,
          customGender: 'Fluido',
        ),
        isNull,
      );
    });
  });
}

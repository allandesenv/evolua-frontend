import 'package:evolua_frontend/l10n/generated/app_localizations.dart';

const minimumSignupAge = 13;
const maxEmailLength = 254;
const minPasswordLength = 6;
const maxPasswordLength = 72;
const minDisplayNameLength = 2;
const maxDisplayNameLength = 80;

const genderMale = 'MALE';
const genderFemale = 'FEMALE';
const genderPreferNotToSay = 'PREFER_NOT_TO_SAY';
const genderCustom = 'CUSTOM';

const validGenderValues = {
  genderMale,
  genderFemale,
  genderPreferNotToSay,
  genderCustom,
};

String normalizeEmail(String value) => value.trim().toLowerCase();

String normalizeDisplayName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String? validateEmail(String? value, AppLocalizations l10n) {
  final email = normalizeEmail(value ?? '');

  if (email.isEmpty) {
    return l10n.authValidationEmailRequired;
  }

  if (email.length > maxEmailLength) {
    return l10n.authValidationEmailMaxLength(maxEmailLength);
  }

  if ('@'.allMatches(email).length != 1) {
    return l10n.authValidationEmailInvalid;
  }

  final parts = email.split('@');
  final local = parts.first;
  final domain = parts.last;

  if (local.isEmpty || domain.isEmpty || !domain.contains('.')) {
    return l10n.authValidationEmailInvalid;
  }

  final localPattern = RegExp(r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+$");
  final domainPattern = RegExp(r'^(?!-)(?:[a-z0-9-]{1,63}\.)+[a-z]{2,63}$');

  if (!localPattern.hasMatch(local) || !domainPattern.hasMatch(domain)) {
    return l10n.authValidationEmailInvalid;
  }

  return null;
}

String? validatePassword(String? value, AppLocalizations l10n) {
  final password = value ?? '';

  if (password.trim().isEmpty) {
    return l10n.authValidationPasswordRequired;
  }

  if (password.length < minPasswordLength) {
    return l10n.authValidationPasswordMinLength(minPasswordLength);
  }

  if (password.length > maxPasswordLength) {
    return l10n.authValidationPasswordMaxLength(maxPasswordLength);
  }

  return null;
}

String? validateConfirmPassword(
  String? value,
  String password,
  AppLocalizations l10n,
) {
  final confirmation = value ?? '';

  if (confirmation.isEmpty) {
    return l10n.authValidationConfirmPasswordRequired;
  }

  if (confirmation != password) {
    return l10n.authValidationPasswordsDoNotMatch;
  }

  return null;
}

String? validateDisplayName(String? value, AppLocalizations l10n) {
  final name = normalizeDisplayName(value ?? '');

  if (name.isEmpty) {
    return l10n.authValidationDisplayNameRequired;
  }

  if (name.length < minDisplayNameLength) {
    return l10n.authValidationDisplayNameMinLength(minDisplayNameLength);
  }

  if (name.length > maxDisplayNameLength) {
    return l10n.authValidationDisplayNameMaxLength(maxDisplayNameLength);
  }

  final namePattern = RegExp(r'^[A-Za-zÀ-ÖØ-öø-ÿ ]+$');
  if (!namePattern.hasMatch(name)) {
    return l10n.authValidationDisplayNameLettersOnly;
  }

  return null;
}

DateTime? parseBirthDateText(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) {
    return null;
  }

  final day = int.tryParse(digits.substring(0, 2));
  final month = int.tryParse(digits.substring(2, 4));
  final year = int.tryParse(digits.substring(4, 8));
  if (day == null || month == null || year == null) {
    return null;
  }

  final parsed = DateTime(year, month, day);
  if (parsed.day != day || parsed.month != month || parsed.year != year) {
    return null;
  }

  return parsed;
}

String formatBirthDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String? validateBirthDateText(
  String? value,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) {
    return l10n.authValidationBirthDateRequired;
  }

  final parsed = parseBirthDateText(raw);
  if (parsed == null) {
    return l10n.authValidationBirthDateFormat;
  }

  return validateBirthDate(parsed, l10n, now: now);
}

String? validateBirthDate(
  DateTime? value,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  if (value == null) {
    return l10n.authValidationBirthDateRequired;
  }

  final today = _dateOnly(now ?? DateTime.now());
  final birthDate = _dateOnly(value);

  if (birthDate.isAfter(today)) {
    return l10n.authValidationBirthDateInvalid;
  }

  final minimumDate = DateTime(
    today.year - minimumSignupAge,
    today.month,
    today.day,
  );
  if (birthDate.isAfter(minimumDate)) {
    return l10n.authValidationMinimumAge(minimumSignupAge);
  }

  return null;
}

String? validateGender(String? value, AppLocalizations l10n) {
  if (value == null || value.isEmpty || !validGenderValues.contains(value)) {
    return l10n.authValidationGenderRequired;
  }

  return null;
}

String? validateCustomGender({
  required String selectedGender,
  required String? customGender,
  required AppLocalizations l10n,
}) {
  if (selectedGender != genderCustom) {
    return null;
  }

  if ((customGender ?? '').trim().isEmpty) {
    return l10n.authValidationCustomGenderRequired;
  }

  return null;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

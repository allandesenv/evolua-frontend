const minimumSignupAge = 13;
const maxEmailLength = 254;
const minPasswordLength = 6;
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

String? validateEmail(String? value) {
  final email = normalizeEmail(value ?? '');

  if (email.isEmpty) {
    return 'Informe seu e-mail.';
  }

  if (email.length > maxEmailLength) {
    return 'Use um e-mail com até $maxEmailLength caracteres.';
  }

  if ('@'.allMatches(email).length != 1) {
    return 'Use um e-mail válido.';
  }

  final parts = email.split('@');
  final local = parts.first;
  final domain = parts.last;

  if (local.isEmpty || domain.isEmpty || !domain.contains('.')) {
    return 'Use um e-mail válido.';
  }

  final localPattern = RegExp(r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+$");
  final domainPattern = RegExp(r'^(?!-)(?:[a-z0-9-]{1,63}\.)+[a-z]{2,63}$');

  if (!localPattern.hasMatch(local) || !domainPattern.hasMatch(domain)) {
    return 'Use um e-mail válido.';
  }

  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';

  if (password.trim().isEmpty) {
    return 'Informe sua senha.';
  }

  if (password.length < minPasswordLength) {
    return 'A senha deve ter ao menos $minPasswordLength caracteres.';
  }

  return null;
}

String? validateDisplayName(String? value) {
  final name = normalizeDisplayName(value ?? '');

  if (name.isEmpty) {
    return 'Informe seu nome.';
  }

  if (name.length < minDisplayNameLength) {
    return 'Informe um nome com ao menos $minDisplayNameLength caracteres.';
  }

  if (name.length > maxDisplayNameLength) {
    return 'Informe um nome com até $maxDisplayNameLength caracteres.';
  }

  final namePattern = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]+$");
  if (!namePattern.hasMatch(name)) {
    return 'Use apenas letras, espaços, hífen ou apóstrofo no nome.';
  }

  return null;
}

String? validateBirthDate(DateTime? value, {DateTime? now}) {
  if (value == null) {
    return 'Informe sua data de nascimento.';
  }

  final today = _dateOnly(now ?? DateTime.now());
  final birthDate = _dateOnly(value);

  if (birthDate.isAfter(today)) {
    return 'Informe uma data de nascimento válida.';
  }

  final minimumDate = DateTime(
    today.year - minimumSignupAge,
    today.month,
    today.day,
  );
  if (birthDate.isAfter(minimumDate)) {
    return 'Você precisa ter pelo menos $minimumSignupAge anos para criar conta.';
  }

  return null;
}

String? validateGender(String? value) {
  if (value == null || value.isEmpty || !validGenderValues.contains(value)) {
    return 'Selecione uma opção de gênero.';
  }

  return null;
}

String? validateCustomGender({
  required String selectedGender,
  required String? customGender,
}) {
  if (selectedGender != genderCustom) {
    return null;
  }

  if ((customGender ?? '').trim().isEmpty) {
    return 'Informe como você se identifica.';
  }

  return null;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/api_error_message.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:evolua_frontend/features/auth/presentation/utils/google_oauth_launcher_provider.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class AuthFormCard extends ConsumerStatefulWidget {
  const AuthFormCard({super.key, this.initialRegisterMode = false});

  final bool initialRegisterMode;

  @override
  ConsumerState<AuthFormCard> createState() => _AuthFormCardState();
}

class _AuthFormCardState extends ConsumerState<AuthFormCard> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _customGenderController = TextEditingController();

  final _displayNameFocusNode = FocusNode();
  final _birthDateFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _customGenderFocusNode = FocusNode();

  bool _isRegisterMode = false;
  bool _isPasswordVisible = false;
  bool _isSubmitting = false;
  bool _isOAuthStarting = false;
  bool _submitted = false;
  DateTime? _birthDate;
  String? _birthDateError;
  String _gender = genderMale;

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.initialRegisterMode;
    _displayNameController.addListener(_handleInputChanged);
    _emailController.addListener(_handleInputChanged);
    _passwordController.addListener(_handleInputChanged);
    _confirmPasswordController.addListener(_handleInputChanged);
    _customGenderController.addListener(_handleInputChanged);
    ref.listenManual(authControllerProvider, (previous, next) {
      final error = next.error;

      if (error == null) {
        return;
      }

      final message = extractApiErrorMessage(
        error,
        fallback: context.l10n.authLoginFallbackError,
      );

      AppSnackBar.show(
        context,
        message: message,
        icon: Icons.info_outline_rounded,
      );
    });
  }

  void _handleInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _customGenderController.dispose();
    _displayNameFocusNode.dispose();
    _birthDateFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _customGenderFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isOAuthStarting) {
      return;
    }

    setState(() {
      _submitted = true;
      if (_isRegisterMode) {
        _birthDate = parseBirthDateText(_birthDateController.text);
        _birthDateError = validateBirthDateText(_birthDateController.text);
      } else {
        _birthDateError = null;
      }
    });

    final isValid = _formKey.currentState!.validate();
    if (!isValid || _birthDateError != null) {
      _focusFirstInvalidField();
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    setState(() => _isSubmitting = true);

    try {
      if (_isRegisterMode) {
        final message = await controller.register(
          displayName: normalizeDisplayName(_displayNameController.text),
          birthDate: _birthDate!,
          gender: _gender,
          customGender: _gender == genderCustom
              ? _customGenderController.text.trim()
              : null,
          email: normalizeEmail(_emailController.text),
          password: _passwordController.text,
        );
        if (message != null && mounted) {
          AppSnackBar.show(
            context,
            message: message,
            icon: Icons.info_outline_rounded,
          );
        }
        return;
      }

      await controller.login(
        email: normalizeEmail(_emailController.text),
        password: _passwordController.text,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _focusFirstInvalidField() {
    if (_isRegisterMode &&
        validateDisplayName(_displayNameController.text) != null) {
      _displayNameFocusNode.requestFocus();
      return;
    }

    if (_isRegisterMode && _birthDateError != null) {
      _birthDateFocusNode.requestFocus();
      return;
    }

    if (validateEmail(_emailController.text) != null) {
      _emailFocusNode.requestFocus();
      return;
    }

    if (validatePassword(_passwordController.text) != null) {
      _passwordFocusNode.requestFocus();
      return;
    }

    if (_isRegisterMode &&
        validateConfirmPassword(
              _confirmPasswordController.text,
              _passwordController.text,
            ) !=
            null) {
      _confirmPasswordFocusNode.requestFocus();
      return;
    }

    if (_isRegisterMode &&
        validateCustomGender(
              selectedGender: _gender,
              customGender: _customGenderController.text,
            ) !=
            null) {
      _customGenderFocusNode.requestFocus();
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isSubmitting || _isOAuthStarting) {
      return;
    }

    final frontendRedirectUri = kIsWeb
        ? Uri.parse(Uri.base.origin).resolve('/auth/google/callback').toString()
        : 'evolua://app/auth/google/callback';
    final startUri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/public/auth/google/start',
    ).replace(queryParameters: {'frontendRedirectUri': frontendRedirectUri});

    setState(() => _isOAuthStarting = true);
    try {
      if (kDebugMode) {
        debugPrint('Google OAuth start requested.');
      }
      await ref.read(googleOAuthLauncherProvider)(startUri.toString());
      if (!kIsWeb && mounted) {
        setState(() => _isOAuthStarting = false);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isOAuthStarting = false);
      if (kDebugMode) {
        debugPrint('Google OAuth start failed: ${error.runtimeType}.');
      }
      AppSnackBar.show(
        context,
        message: context.l10n.authGoogleStartError,
        icon: Icons.info_outline_rounded,
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ForgotPasswordDialog(
        initialEmail: normalizeEmail(_emailController.text),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      locale: Localizations.localeOf(context),
    );
    if (selected != null) {
      setState(() {
        _birthDate = selected;
        _birthDateController.text = formatBirthDate(selected);
        _birthDateError = _submitted
            ? validateBirthDateText(_birthDateController.text)
            : null;
      });
    }
  }

  void _handleBirthDateChanged(String value) {
    setState(() {
      _birthDate = parseBirthDateText(value);
      _birthDateError = _submitted ? validateBirthDateText(value) : null;
    });
  }

  void _switchMode(bool isRegisterMode) {
    setState(() {
      _isRegisterMode = isRegisterMode;
      _submitted = false;
      _birthDateError = null;
      _displayNameController.clear();
      _birthDateController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _customGenderController.clear();
      _birthDate = null;
      _gender = genderMale;
    });
  }

  bool get _canSubmit {
    if (_isOAuthStarting || _isSubmitting) {
      return false;
    }

    if (!_isRegisterMode) {
      return true;
    }

    return normalizeDisplayName(_displayNameController.text).isNotEmpty &&
        parseBirthDateText(_birthDateController.text) != null &&
        normalizeEmail(_emailController.text).isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        validGenderValues.contains(_gender);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading || _isSubmitting || _isOAuthStarting;
    final canSubmit = !isLoading && _canSubmit;
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;

        return PrimaryPanel(
          padding: EdgeInsets.all(compact ? 18 : 24),
          semanticLabel: l10n.authFormSemanticLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? double.infinity : null,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment<bool>(
                      value: false,
                      icon: const Icon(Icons.login_rounded),
                      label: Text(l10n.authLoginTab),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(l10n.authRegisterTab),
                    ),
                  ],
                  selected: {_isRegisterMode},
                  onSelectionChanged: isLoading
                      ? null
                      : (selection) => _switchMode(selection.first),
                ),
              ),
              SizedBox(height: compact ? 16 : 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : _handleGoogleLogin,
                  icon: _isOAuthStarting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_circle_rounded),
                  label: Text(l10n.authGoogleContinue),
                ),
              ),
              SizedBox(height: compact ? 16 : 18),
              AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isRegisterMode) ...[
                        TextFormField(
                          controller: _displayNameController,
                          focusNode: _displayNameFocusNode,
                          autofillHints: const [AutofillHints.name],
                          maxLength: maxDisplayNameLength,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l10n.authDisplayNameLabel,
                            hintText: l10n.authDisplayNameHint,
                            prefixIcon: const Icon(Icons.badge_rounded),
                          ),
                          validator: validateDisplayName,
                        ),
                        SizedBox(height: compact ? 12 : 14),
                        TextFormField(
                          key: const Key('auth-birth-date-field'),
                          controller: _birthDateController,
                          focusNode: _birthDateFocusNode,
                          enabled: !isLoading,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: const [_BirthDateInputFormatter()],
                          decoration: InputDecoration(
                            labelText: l10n.authBirthDateLabel,
                            hintText: l10n.authBirthDateHint,
                            prefixIcon: const Icon(Icons.cake_rounded),
                            errorText: _submitted ? _birthDateError : null,
                            suffixIcon: IconButton(
                              tooltip: l10n.authBirthDateOpenPicker,
                              onPressed: isLoading ? null : _pickBirthDate,
                              icon: const Icon(Icons.calendar_month_rounded),
                            ),
                          ),
                          validator: (_) => _birthDateError,
                          onChanged: _handleBirthDateChanged,
                        ),
                        SizedBox(height: compact ? 12 : 14),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: InputDecoration(
                            labelText: l10n.authGenderLabel,
                            prefixIcon: const Icon(Icons.wc_rounded),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: genderMale,
                              child: Text(l10n.authGenderMale),
                            ),
                            DropdownMenuItem(
                              value: genderFemale,
                              child: Text(l10n.authGenderFemale),
                            ),
                            DropdownMenuItem(
                              value: genderPreferNotToSay,
                              child: Text(l10n.authGenderPreferNotToSay),
                            ),
                            DropdownMenuItem(
                              value: genderCustom,
                              child: Text(l10n.authGenderCustom),
                            ),
                          ],
                          validator: validateGender,
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  setState(() => _gender = value ?? genderMale);
                                },
                        ),
                        if (_gender == genderCustom) ...[
                          SizedBox(height: compact ? 12 : 14),
                          TextFormField(
                            controller: _customGenderController,
                            focusNode: _customGenderFocusNode,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.authCustomGenderLabel,
                              hintText: l10n.authCustomGenderHint,
                              prefixIcon: const Icon(Icons.edit_note_rounded),
                            ),
                            validator: (value) => validateCustomGender(
                              selectedGender: _gender,
                              customGender: value,
                            ),
                          ),
                        ],
                        SizedBox(height: compact ? 12 : 14),
                      ],
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        maxLength: maxEmailLength,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.authEmailLabel,
                          hintText: l10n.authEmailHint,
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                        validator: validateEmail,
                      ),
                      SizedBox(height: compact ? 12 : 14),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: !_isPasswordVisible,
                        autofillHints: const [AutofillHints.password],
                        maxLength: maxPasswordLength,
                        textInputAction: _isRegisterMode
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: l10n.authPasswordLabel,
                          hintText: l10n.authPasswordHint,
                          helperText: _isRegisterMode
                              ? l10n.authPasswordRules
                              : null,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _isPasswordVisible
                                ? l10n.authHidePassword
                                : l10n.authShowPassword,
                            onPressed: () {
                              setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              );
                            },
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                        validator: validatePassword,
                      ),
                      if (_isRegisterMode) ...[
                        SizedBox(height: compact ? 12 : 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          obscureText: !_isPasswordVisible,
                          autofillHints: const [AutofillHints.newPassword],
                          maxLength: maxPasswordLength,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: l10n.authConfirmPasswordLabel,
                            hintText: l10n.authConfirmPasswordHint,
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                          ),
                          validator: (value) => validateConfirmPassword(
                            value,
                            _passwordController.text,
                          ),
                        ),
                      ],
                      if (!_isRegisterMode) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            onPressed: isLoading ? null : _handleForgotPassword,
                            child: Text(l10n.authForgotPassword),
                          ),
                        ),
                      ],
                      SizedBox(height: compact ? 16 : 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canSubmit ? _submit : null,
                          key: const Key('auth-submit-button'),
                          child: _isSubmitting && !_isOAuthStarting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isRegisterMode
                                      ? l10n.authRegisterTab
                                      : l10n.authLoginTab,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BirthDateInputFormatter extends TextInputFormatter {
  const _BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();

    for (var index = 0; index < limited.length; index += 1) {
      if (index == 2 || index == 4) {
        buffer.write('/');
      }
      buffer.write(limited[index]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  ConsumerState<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSending = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSending) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .forgotPassword(email: normalizeEmail(_emailController.text));
      if (!mounted) {
        return;
      }
      setState(() => _sent = true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = _forgotPasswordErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _forgotPasswordErrorMessage(Object error) {
    if (error is DioException &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout)) {
      return context.l10n.authForgotPasswordTimeout;
    }

    return extractApiErrorMessage(
      error,
      fallback: context.l10n.authForgotPasswordError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.authForgotPasswordTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.authForgotPasswordBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              autofocus: true,
              enabled: !_isSending,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.authEmailLabel,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              validator: validateEmail,
              onFieldSubmitted: _isSending ? null : (_) => _submit(),
            ),
            if (_sent) ...[
              const SizedBox(height: 16),
              _ForgotPasswordStatusMessage(
                icon: Icons.mark_email_unread_rounded,
                message: l10n.authForgotPasswordSuccess,
                color: AppColors.accent,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _ForgotPasswordStatusMessage(
                icon: Icons.info_outline_rounded,
                message: _errorMessage!,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: Text(_sent ? l10n.commonClose : l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: _isSending ? null : _submit,
          icon: _isSending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mark_email_unread_rounded),
          label: Text(
            _isSending
                ? l10n.authSendingLink
                : _sent
                ? l10n.authResendLink
                : l10n.authSendLink,
          ),
        ),
      ],
    );
  }
}

class _ForgotPasswordStatusMessage extends StatelessWidget {
  const _ForgotPasswordStatusMessage({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

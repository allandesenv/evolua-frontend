// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Evolua';

  @override
  String get authFormSemanticLabel => 'Authentication form';

  @override
  String get authLoginTab => 'Sign in';

  @override
  String get authRegisterTab => 'Create account';

  @override
  String get authGoogleContinue => 'Continue with Google';

  @override
  String get authLoginFallbackError =>
      'We could not authenticate you. Review your details and try again.';

  @override
  String get authGoogleStartError =>
      'We could not start Google sign-in. Try again.';

  @override
  String get authDisplayNameLabel => 'Name';

  @override
  String get authDisplayNameHint => 'How would you like to be called?';

  @override
  String get authBirthDateLabel => 'Birth date';

  @override
  String get authBirthDateEmpty => 'Select your date';

  @override
  String get authBirthDateHint => 'dd/mm/yyyy';

  @override
  String get authBirthDateOpenPicker => 'Open calendar';

  @override
  String get authGenderLabel => 'Gender';

  @override
  String get authGenderMale => 'Male';

  @override
  String get authGenderFemale => 'Female';

  @override
  String get authGenderPreferNotToSay => 'Prefer not to say';

  @override
  String get authGenderCustom => 'Custom';

  @override
  String get authCustomGenderLabel => 'How do you identify?';

  @override
  String get authCustomGenderHint => 'Write it your way';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'you@evolua.app';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => '6 to 72 characters';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authConfirmPasswordHint => 'Enter the password again';

  @override
  String get authPasswordRules =>
      'Use 6 to 72 characters. You may use letters, numbers, and symbols.';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authForgotPassword => 'Forgot password';

  @override
  String get authForgotPasswordTitle => 'Recover password';

  @override
  String get authForgotPasswordBody =>
      'Enter your access email. If it is registered, we will send a link to create a new password.';

  @override
  String get authForgotPasswordSuccess =>
      'If this email is registered, we will send recovery instructions.';

  @override
  String get authForgotPasswordError =>
      'We could not request recovery right now.';

  @override
  String get authForgotPasswordTimeout =>
      'We could not confirm the send right now. Try again in a moment.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonSend => 'Send';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get authSendLink => 'Send link';

  @override
  String get authResendLink => 'Resend link';

  @override
  String get authSendingLink => 'Sending...';

  @override
  String get resetPasswordSemanticLabel => 'Reset password';

  @override
  String get resetPasswordInvalidLink => 'Invalid recovery link.';

  @override
  String get resetPasswordCompletedSnack =>
      'Password reset. You can sign in now.';

  @override
  String get resetPasswordError => 'We could not reset your password.';

  @override
  String get resetPasswordCreateTitle => 'Create new password';

  @override
  String get resetPasswordCreateBody =>
      'Choose a password with at least 6 characters to return to Evolua.';

  @override
  String get resetPasswordNewLabel => 'New password';

  @override
  String get resetPasswordConfirmLabel => 'Confirm new password';

  @override
  String get resetPasswordMismatch => 'Passwords do not match.';

  @override
  String get resetPasswordSubmit => 'Reset password';

  @override
  String get resetPasswordBackToLogin => 'Back to sign in';

  @override
  String get resetPasswordSuccessTitle => 'Password reset';

  @override
  String get resetPasswordSuccessBody =>
      'You can now sign in with your new password.';

  @override
  String get authHeroTitle => 'Continue your journey';

  @override
  String get authHeroSubtitle =>
      'Access your self-knowledge space in a few seconds.';

  @override
  String get authHeroQuickCheckIn => 'Quick check-in';

  @override
  String get authHeroShortTrails => 'Short trails';

  @override
  String get authHeroReflections => 'Current reflections';

  @override
  String get navHome => 'Home';

  @override
  String get navTrails => 'Trails';

  @override
  String get navSpaces => 'Spaces';

  @override
  String get navMirror => 'Mirror';

  @override
  String get navAdminPanel => 'Admin Panel';

  @override
  String get navProfile => 'Profile';

  @override
  String get avatarFutureMessages => 'Future messages';

  @override
  String get avatarPlans => 'Plans and subscriptions';

  @override
  String get avatarEvolutionMirror => 'Evolution Mirror';

  @override
  String get avatarLogout => 'Sign out';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSectionSubtitle =>
      'Choose how Evolua should appear to you.';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get languageEnglish => 'English (US)';

  @override
  String get languageSystem => 'Use system language';

  @override
  String get settingsPrivacyTitle => 'Settings and privacy';

  @override
  String get settingsPreferencesSaved => 'Preferences saved safely.';

  @override
  String get settingsVisualPreferencesSaved =>
      'Visual preferences saved comfortably.';

  @override
  String homeDailyMorningTitle(Object name) {
    return 'Good morning, $name';
  }

  @override
  String get homeDailyMorningTitleNoName => 'Good morning';

  @override
  String get homeDailyMorningBody =>
      'Start the day with presence. Choose one simple intention and one possible micro-action.';

  @override
  String get homeDailyMorningPrimary => 'Start Daily Ritual';

  @override
  String get homeDailyDayTitle => 'How is your day so far?';

  @override
  String get homeDailyDayBody =>
      'Take a short pause to notice your state and choose the next step.';

  @override
  String get homeDailyDayPrimary => 'Check in';

  @override
  String get homeDailyDaySecondary => 'See next step';

  @override
  String get homeDailyEveningTitle => 'Shall we close the day?';

  @override
  String get homeDailyEveningBody =>
      'Review what felt heavy, acknowledge what was good, and release what you do not need to carry.';

  @override
  String get homeDailyEveningPrimary => 'Start Evening Closing';

  @override
  String get homeDailyEveningSecondary => 'Write reflection';

  @override
  String get homeDailyRitualDone => 'Daily Ritual completed';

  @override
  String get homeDailyClosingDone => 'Evening Closing completed';

  @override
  String get homeDailyViewRitual => 'View my ritual';

  @override
  String get homeFutureLetter => 'Letter to the future';

  @override
  String get homeRecentReflection => 'Recent reflection';

  @override
  String get homeQuickInsight => 'Quick insight';

  @override
  String get homeEvolutionMilestone => 'Evolution milestone';

  @override
  String get homeIntelligentReadingEyebrow => 'What does this mean?';

  @override
  String get homeIntelligentReadingTitle => 'Intelligent reading';

  @override
  String get homeIntelligentReadingEmpty =>
      'After your next check-in, AI will summarize the moment and turn the reading into one simple action.';

  @override
  String get homeFullAnalysis => 'View full analysis';

  @override
  String homeEnergyBullet(Object value) {
    return 'Energy: $value/10';
  }

  @override
  String homeStateBullet(Object value) {
    return 'State: $value';
  }

  @override
  String homeBestResponseBullet(Object value) {
    return 'Best response now: $value';
  }

  @override
  String get trailCatalog => 'Catalog';

  @override
  String get trailMyJourney => 'My journey';

  @override
  String get trailStart => 'Start trail';

  @override
  String get trailCompleteJourney => 'Full journey';

  @override
  String get trailViewCatalog => 'View catalog';

  @override
  String get trailNoActiveJourney => 'No active journey.';

  @override
  String get trailVideo => 'Video';

  @override
  String get trailListen => 'Listen';

  @override
  String get trailPause => 'Pause';

  @override
  String get trailStop => 'Stop';

  @override
  String get trailFullscreen => 'Fullscreen';

  @override
  String get trailSpeed => 'Speed';

  @override
  String get trailVideoUnavailable => 'We could not prepare this video.';

  @override
  String get adminTrailsTitle => 'Trail admin';

  @override
  String get adminNotificationsTitle => 'Notification admin';

  @override
  String get spacesFeatured => 'Featured';

  @override
  String get spacesReflections => 'Reflections';

  @override
  String get spacesMine => 'Mine';

  @override
  String get futureMessagesTitle => 'Future messages';

  @override
  String get mirrorTitle => 'Evolution Mirror';

  @override
  String get profileChangePhoto => 'Change photo';

  @override
  String get profileUpdate => 'Refresh';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get plansTitle => 'Plans and subscriptions';

  @override
  String get checkInTitle => 'Check-in';

  @override
  String get checkInSemanticLabel => 'Daily check-in';

  @override
  String get checkInEyebrow => 'How am I?';

  @override
  String get checkInPromptTitle => 'Start with your state right now';

  @override
  String get checkInPromptSubtitle =>
      'A short check-in gives context to your brief daily record.';

  @override
  String get checkInMoreStatesTooltip => 'See more states';

  @override
  String get checkInMoreStates => 'More states';

  @override
  String checkInSelectedState(Object state) {
    return 'Selected state: $state';
  }

  @override
  String get checkInOtherMoodLabel => 'Describe it in your words';

  @override
  String get checkInOtherMoodHint => 'Optional: write how you are feeling';

  @override
  String checkInEnergyLabel(Object value) {
    return 'Perceived energy: $value/10';
  }

  @override
  String get checkInReflectionLabel => 'If you want, share the reason';

  @override
  String get checkInReflectionHint =>
      'A simple sentence helps the reading become more precise.';

  @override
  String get checkInSubmit => 'Check in';

  @override
  String get checkInNotNow => 'Not now';

  @override
  String get checkInSavedSnack => 'Check-in saved. Continue at your pace.';

  @override
  String get checkInSaveError => 'We could not save your check-in.';

  @override
  String get checkInDeepReadingTitle =>
      'Would you like to unlock one more emotional reading?';

  @override
  String get checkInDeepReadingMessage =>
      'Your check-in was saved. The basic reading remains available, and you can unlock a deeper reading by watching an ad or subscribing to Premium.';

  @override
  String get checkInDeepReadingReward =>
      'Reward: +1 deeper emotional reading today.';

  @override
  String get checkInDeepReadingUnlocked => 'Deeper reading unlocked for today.';

  @override
  String get checkInRewardAdNotConfirmed =>
      'We could not confirm the ad right now. Your check-in remains saved.';

  @override
  String get checkInPremiumAction => 'Subscribe to Premium';

  @override
  String get checkInChooseStateTitle => 'Choose a state';

  @override
  String get checkInSearchState => 'Search state';

  @override
  String get checkInRecentStates => 'Recent';

  @override
  String get checkInAiSuggestedStates => 'Suggested by AI';

  @override
  String get checkInMoodGroupEmotional => 'Emotional';

  @override
  String get checkInMoodGroupMental => 'Mental';

  @override
  String get checkInMoodGroupPhysical => 'Physical';

  @override
  String get checkInMoodGroupBehavioral => 'Behavioral';

  @override
  String get checkInMoodGroupOther => 'Other';

  @override
  String get checkInMoodCalm => 'Calm';

  @override
  String get checkInMoodAnxiety => 'Anxiety';

  @override
  String get checkInMoodTiredness => 'Tiredness';

  @override
  String get checkInMoodDistraction => 'Distraction';

  @override
  String get checkInMoodSadness => 'Sadness';

  @override
  String get checkInMoodEnthusiasm => 'Enthusiasm';

  @override
  String get checkInMoodIrritation => 'Irritation';

  @override
  String get checkInMoodHope => 'Hope';

  @override
  String get checkInMoodOverload => 'Overload';

  @override
  String get checkInMoodFocus => 'Focus';

  @override
  String get checkInMoodConfusion => 'Confusion';

  @override
  String get checkInMoodCreativity => 'Creativity';

  @override
  String get checkInMoodAcceleration => 'Acceleration';

  @override
  String get checkInMoodBlock => 'Block';

  @override
  String get checkInMoodEnergy => 'Energy';

  @override
  String get checkInMoodTension => 'Tension';

  @override
  String get checkInMoodLightness => 'Lightness';

  @override
  String get checkInMoodSleepiness => 'Sleepiness';

  @override
  String get checkInMoodAgitation => 'Agitation';

  @override
  String get checkInMoodAvoidance => 'Avoidance';

  @override
  String get checkInMoodProductivity => 'Productivity';

  @override
  String get checkInMoodIsolation => 'Isolation';

  @override
  String get checkInMoodConnection => 'Connection';

  @override
  String get checkInMoodProcrastination => 'Procrastination';

  @override
  String get checkInMoodConsistency => 'Consistency';

  @override
  String get checkInMoodOther => 'Other state';

  @override
  String get dailyRitualCarryMorning => 'Take this with you today';

  @override
  String get dailyRitualCarryEvening => 'Keep this from your day';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');

  @override
  String get appTitle => 'Evolua';

  @override
  String get authFormSemanticLabel => 'Authentication form';

  @override
  String get authLoginTab => 'Sign in';

  @override
  String get authRegisterTab => 'Create account';

  @override
  String get authGoogleContinue => 'Continue with Google';

  @override
  String get authLoginFallbackError =>
      'We could not authenticate you. Review your details and try again.';

  @override
  String get authGoogleStartError =>
      'We could not start Google sign-in. Try again.';

  @override
  String get authDisplayNameLabel => 'Name';

  @override
  String get authDisplayNameHint => 'How would you like to be called?';

  @override
  String get authBirthDateLabel => 'Birth date';

  @override
  String get authBirthDateEmpty => 'Select your date';

  @override
  String get authBirthDateHint => 'dd/mm/yyyy';

  @override
  String get authBirthDateOpenPicker => 'Open calendar';

  @override
  String get authGenderLabel => 'Gender';

  @override
  String get authGenderMale => 'Male';

  @override
  String get authGenderFemale => 'Female';

  @override
  String get authGenderPreferNotToSay => 'Prefer not to say';

  @override
  String get authGenderCustom => 'Custom';

  @override
  String get authCustomGenderLabel => 'How do you identify?';

  @override
  String get authCustomGenderHint => 'Write it your way';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'you@evolua.app';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => '6 to 72 characters';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authConfirmPasswordHint => 'Enter the password again';

  @override
  String get authPasswordRules =>
      'Use 6 to 72 characters. You may use letters, numbers, and symbols.';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authForgotPassword => 'Forgot password';

  @override
  String get authForgotPasswordTitle => 'Recover password';

  @override
  String get authForgotPasswordBody =>
      'Enter your access email. If it is registered, we will send a link to create a new password.';

  @override
  String get authForgotPasswordSuccess =>
      'If this email is registered, we will send recovery instructions.';

  @override
  String get authForgotPasswordError =>
      'We could not request recovery right now.';

  @override
  String get authForgotPasswordTimeout =>
      'We could not confirm the send right now. Try again in a moment.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonSend => 'Send';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get authSendLink => 'Send link';

  @override
  String get authResendLink => 'Resend link';

  @override
  String get authSendingLink => 'Sending...';

  @override
  String get resetPasswordSemanticLabel => 'Reset password';

  @override
  String get resetPasswordInvalidLink => 'Invalid recovery link.';

  @override
  String get resetPasswordCompletedSnack =>
      'Password reset. You can sign in now.';

  @override
  String get resetPasswordError => 'We could not reset your password.';

  @override
  String get resetPasswordCreateTitle => 'Create new password';

  @override
  String get resetPasswordCreateBody =>
      'Choose a password with at least 6 characters to return to Evolua.';

  @override
  String get resetPasswordNewLabel => 'New password';

  @override
  String get resetPasswordConfirmLabel => 'Confirm new password';

  @override
  String get resetPasswordMismatch => 'Passwords do not match.';

  @override
  String get resetPasswordSubmit => 'Reset password';

  @override
  String get resetPasswordBackToLogin => 'Back to sign in';

  @override
  String get resetPasswordSuccessTitle => 'Password reset';

  @override
  String get resetPasswordSuccessBody =>
      'You can now sign in with your new password.';

  @override
  String get authHeroTitle => 'Continue your journey';

  @override
  String get authHeroSubtitle =>
      'Access your self-knowledge space in a few seconds.';

  @override
  String get authHeroQuickCheckIn => 'Quick check-in';

  @override
  String get authHeroShortTrails => 'Short trails';

  @override
  String get authHeroReflections => 'Current reflections';

  @override
  String get navHome => 'Home';

  @override
  String get navTrails => 'Trails';

  @override
  String get navSpaces => 'Spaces';

  @override
  String get navMirror => 'Mirror';

  @override
  String get navAdminPanel => 'Admin Panel';

  @override
  String get navProfile => 'Profile';

  @override
  String get avatarFutureMessages => 'Future messages';

  @override
  String get avatarPlans => 'Plans and subscriptions';

  @override
  String get avatarEvolutionMirror => 'Evolution Mirror';

  @override
  String get avatarLogout => 'Sign out';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSectionSubtitle =>
      'Choose how Evolua should appear to you.';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get languageEnglish => 'English (US)';

  @override
  String get languageSystem => 'Use system language';

  @override
  String get settingsPrivacyTitle => 'Settings and privacy';

  @override
  String get settingsPreferencesSaved => 'Preferences saved safely.';

  @override
  String get settingsVisualPreferencesSaved =>
      'Visual preferences saved comfortably.';

  @override
  String homeDailyMorningTitle(Object name) {
    return 'Good morning, $name';
  }

  @override
  String get homeDailyMorningTitleNoName => 'Good morning';

  @override
  String get homeDailyMorningBody =>
      'Start the day with presence. Choose one simple intention and one possible micro-action.';

  @override
  String get homeDailyMorningPrimary => 'Start Daily Ritual';

  @override
  String get homeDailyDayTitle => 'How is your day so far?';

  @override
  String get homeDailyDayBody =>
      'Take a short pause to notice your state and choose the next step.';

  @override
  String get homeDailyDayPrimary => 'Check in';

  @override
  String get homeDailyDaySecondary => 'See next step';

  @override
  String get homeDailyEveningTitle => 'Shall we close the day?';

  @override
  String get homeDailyEveningBody =>
      'Review what felt heavy, acknowledge what was good, and release what you do not need to carry.';

  @override
  String get homeDailyEveningPrimary => 'Start Evening Closing';

  @override
  String get homeDailyEveningSecondary => 'Write reflection';

  @override
  String get homeDailyRitualDone => 'Daily Ritual completed';

  @override
  String get homeDailyClosingDone => 'Evening Closing completed';

  @override
  String get homeDailyViewRitual => 'View my ritual';

  @override
  String get homeFutureLetter => 'Letter to the future';

  @override
  String get homeRecentReflection => 'Recent reflection';

  @override
  String get homeQuickInsight => 'Quick insight';

  @override
  String get homeEvolutionMilestone => 'Evolution milestone';

  @override
  String get homeIntelligentReadingEyebrow => 'What does this mean?';

  @override
  String get homeIntelligentReadingTitle => 'Intelligent reading';

  @override
  String get homeIntelligentReadingEmpty =>
      'After your next check-in, AI will summarize the moment and turn the reading into one simple action.';

  @override
  String get homeFullAnalysis => 'View full analysis';

  @override
  String homeEnergyBullet(Object value) {
    return 'Energy: $value/10';
  }

  @override
  String homeStateBullet(Object value) {
    return 'State: $value';
  }

  @override
  String homeBestResponseBullet(Object value) {
    return 'Best response now: $value';
  }

  @override
  String get trailCatalog => 'Catalog';

  @override
  String get trailMyJourney => 'My journey';

  @override
  String get trailStart => 'Start trail';

  @override
  String get trailCompleteJourney => 'Full journey';

  @override
  String get trailViewCatalog => 'View catalog';

  @override
  String get trailNoActiveJourney => 'No active journey.';

  @override
  String get trailVideo => 'Video';

  @override
  String get trailListen => 'Listen';

  @override
  String get trailPause => 'Pause';

  @override
  String get trailStop => 'Stop';

  @override
  String get trailFullscreen => 'Fullscreen';

  @override
  String get trailSpeed => 'Speed';

  @override
  String get trailVideoUnavailable => 'We could not prepare this video.';

  @override
  String get adminTrailsTitle => 'Trail admin';

  @override
  String get adminNotificationsTitle => 'Notification admin';

  @override
  String get spacesFeatured => 'Featured';

  @override
  String get spacesReflections => 'Reflections';

  @override
  String get spacesMine => 'Mine';

  @override
  String get futureMessagesTitle => 'Future messages';

  @override
  String get mirrorTitle => 'Evolution Mirror';

  @override
  String get profileChangePhoto => 'Change photo';

  @override
  String get profileUpdate => 'Refresh';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get plansTitle => 'Plans and subscriptions';

  @override
  String get checkInTitle => 'Check-in';

  @override
  String get checkInSemanticLabel => 'Daily check-in';

  @override
  String get checkInEyebrow => 'How am I?';

  @override
  String get checkInPromptTitle => 'Start with your state right now';

  @override
  String get checkInPromptSubtitle =>
      'A short check-in gives context to your brief daily record.';

  @override
  String get checkInMoreStatesTooltip => 'See more states';

  @override
  String get checkInMoreStates => 'More states';

  @override
  String checkInSelectedState(Object state) {
    return 'Selected state: $state';
  }

  @override
  String get checkInOtherMoodLabel => 'Describe it in your words';

  @override
  String get checkInOtherMoodHint => 'Optional: write how you are feeling';

  @override
  String checkInEnergyLabel(Object value) {
    return 'Perceived energy: $value/10';
  }

  @override
  String get checkInReflectionLabel => 'If you want, share the reason';

  @override
  String get checkInReflectionHint =>
      'A simple sentence helps the reading become more precise.';

  @override
  String get checkInSubmit => 'Check in';

  @override
  String get checkInNotNow => 'Not now';

  @override
  String get checkInSavedSnack => 'Check-in saved. Continue at your pace.';

  @override
  String get checkInSaveError => 'We could not save your check-in.';

  @override
  String get checkInDeepReadingTitle =>
      'Would you like to unlock one more emotional reading?';

  @override
  String get checkInDeepReadingMessage =>
      'Your check-in was saved. The basic reading remains available, and you can unlock a deeper reading by watching an ad or subscribing to Premium.';

  @override
  String get checkInDeepReadingReward =>
      'Reward: +1 deeper emotional reading today.';

  @override
  String get checkInDeepReadingUnlocked => 'Deeper reading unlocked for today.';

  @override
  String get checkInRewardAdNotConfirmed =>
      'We could not confirm the ad right now. Your check-in remains saved.';

  @override
  String get checkInPremiumAction => 'Subscribe to Premium';

  @override
  String get checkInChooseStateTitle => 'Choose a state';

  @override
  String get checkInSearchState => 'Search state';

  @override
  String get checkInRecentStates => 'Recent';

  @override
  String get checkInAiSuggestedStates => 'Suggested by AI';

  @override
  String get checkInMoodGroupEmotional => 'Emotional';

  @override
  String get checkInMoodGroupMental => 'Mental';

  @override
  String get checkInMoodGroupPhysical => 'Physical';

  @override
  String get checkInMoodGroupBehavioral => 'Behavioral';

  @override
  String get checkInMoodGroupOther => 'Other';

  @override
  String get checkInMoodCalm => 'Calm';

  @override
  String get checkInMoodAnxiety => 'Anxiety';

  @override
  String get checkInMoodTiredness => 'Tiredness';

  @override
  String get checkInMoodDistraction => 'Distraction';

  @override
  String get checkInMoodSadness => 'Sadness';

  @override
  String get checkInMoodEnthusiasm => 'Enthusiasm';

  @override
  String get checkInMoodIrritation => 'Irritation';

  @override
  String get checkInMoodHope => 'Hope';

  @override
  String get checkInMoodOverload => 'Overload';

  @override
  String get checkInMoodFocus => 'Focus';

  @override
  String get checkInMoodConfusion => 'Confusion';

  @override
  String get checkInMoodCreativity => 'Creativity';

  @override
  String get checkInMoodAcceleration => 'Acceleration';

  @override
  String get checkInMoodBlock => 'Block';

  @override
  String get checkInMoodEnergy => 'Energy';

  @override
  String get checkInMoodTension => 'Tension';

  @override
  String get checkInMoodLightness => 'Lightness';

  @override
  String get checkInMoodSleepiness => 'Sleepiness';

  @override
  String get checkInMoodAgitation => 'Agitation';

  @override
  String get checkInMoodAvoidance => 'Avoidance';

  @override
  String get checkInMoodProductivity => 'Productivity';

  @override
  String get checkInMoodIsolation => 'Isolation';

  @override
  String get checkInMoodConnection => 'Connection';

  @override
  String get checkInMoodProcrastination => 'Procrastination';

  @override
  String get checkInMoodConsistency => 'Consistency';

  @override
  String get checkInMoodOther => 'Other state';

  @override
  String get dailyRitualCarryMorning => 'Take this with you today';

  @override
  String get dailyRitualCarryEvening => 'Keep this from your day';
}

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
  String get authRegisterFallbackError =>
      'We could not create your account right now. Check your details and try again.';

  @override
  String get authRegisterEmailExistsError =>
      'This email is already registered. Sign in to your account or use another email.';

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
  String get authValidationEmailRequired => 'Enter your email.';

  @override
  String authValidationEmailMaxLength(Object maxLength) {
    return 'Use an email with up to $maxLength characters.';
  }

  @override
  String get authValidationEmailInvalid => 'Use a valid email.';

  @override
  String get authValidationPasswordRequired => 'Enter your password.';

  @override
  String authValidationPasswordMinLength(Object minLength) {
    return 'The password must have at least $minLength characters.';
  }

  @override
  String authValidationPasswordMaxLength(Object maxLength) {
    return 'Use a password with up to $maxLength characters.';
  }

  @override
  String get authValidationConfirmPasswordRequired => 'Confirm your password.';

  @override
  String get authValidationPasswordsDoNotMatch => 'The passwords do not match.';

  @override
  String get authValidationDisplayNameRequired => 'Enter your name.';

  @override
  String authValidationDisplayNameMinLength(Object minLength) {
    return 'Enter a name with at least $minLength characters.';
  }

  @override
  String authValidationDisplayNameMaxLength(Object maxLength) {
    return 'Enter a name with up to $maxLength characters.';
  }

  @override
  String get authValidationDisplayNameLettersOnly =>
      'Use only letters, spaces, and accents in the name.';

  @override
  String get authValidationBirthDateRequired => 'Enter your birth date.';

  @override
  String get authValidationBirthDateFormat =>
      'Use a valid date in dd/mm/yyyy format.';

  @override
  String get authValidationBirthDateInvalid => 'Enter a valid birth date.';

  @override
  String authValidationMinimumAge(Object minimumAge) {
    return 'You must be at least $minimumAge years old to create an account.';
  }

  @override
  String get authValidationGenderRequired => 'Select a gender option.';

  @override
  String get authValidationCustomGenderRequired => 'Enter how you identify.';

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
  String get commonSaving => 'Saving...';

  @override
  String get commonSending => 'Sending...';

  @override
  String get commonSend => 'Send';

  @override
  String get commonRetry => 'Try again';

  @override
  String get routerBootErrorTitle => 'We could not start Evolua right now.';

  @override
  String get routerBootErrorBody =>
      'Check your connection and try again in a moment.';

  @override
  String get routerNotFoundTitle => 'We could not find this page.';

  @override
  String get routerNotFoundBody =>
      'The link may have changed or may no longer be available.';

  @override
  String get routerBackToEvolua => 'Back to Evolua';

  @override
  String get dashboardCareRitualReceived =>
      'New ritual received from your therapist.';

  @override
  String get dashboardCareGuidanceReceived =>
      'New guidance from your therapist.';

  @override
  String get dashboardEmailVerificationSent =>
      'We sent a new confirmation email.';

  @override
  String get dashboardEmailVerificationResendError =>
      'We could not resend it right now. Try again in a moment.';

  @override
  String get dashboardEmailVerificationConfirmed =>
      'Email confirmed. Thank you!';

  @override
  String get dashboardEmailVerificationStillPending =>
      'We have not detected the confirmation yet. Check your email and try again.';

  @override
  String get appUpdateRecommendedTitle => 'New version available';

  @override
  String get appUpdateRecommendedFallbackMessage =>
      'Update Evolua to receive improvements, fixes, and a more stable experience.';

  @override
  String get appUpdateRequiredTitle => 'Update required';

  @override
  String get appUpdateRequiredFallbackMessage =>
      'This version of Evolua is no longer compatible with important security and stability improvements. Update to continue.';

  @override
  String get appUpdateDismiss => 'Not now';

  @override
  String get appUpdateAction => 'Update';

  @override
  String get appUpdateGooglePlayAction => 'Update on Google Play';

  @override
  String get dashboardCareRecommendationReceived =>
      'New guidance from your therapist.';

  @override
  String get dashboardMainNavigationSemantic => 'Main navigation';

  @override
  String get dashboardSidebarMenuSemantic => 'Side menu';

  @override
  String get dashboardAuthenticatedHeaderSemantic =>
      'Authenticated area header';

  @override
  String get dashboardMentorTitle => 'Evolua Mentor';

  @override
  String get dashboardEmailVerificationNotice =>
      'Confirm your email to keep your account safer.';

  @override
  String get dashboardEmailVerificationResend => 'Resend email';

  @override
  String get dashboardEmailVerificationRefreshing => 'Updating...';

  @override
  String get dashboardEmailVerificationAlreadyConfirmed =>
      'I already confirmed';

  @override
  String get dashboardCheckingCheckIn => 'Checking check-in';

  @override
  String get accountOpenMenuTooltip => 'Open account menu';

  @override
  String get accountConnectTherapist => 'Connect Therapist';

  @override
  String get accountHelpSupport => 'Help and support';

  @override
  String get accountDisplayAccessibility => 'Display and accessibility';

  @override
  String get accountFeedback => 'Give feedback';

  @override
  String get accountFallbackEmail => 'you@evolua.app';

  @override
  String get commonUnderstood => 'Got it';

  @override
  String get checkInMicrophoneUnavailable =>
      'The microphone is not available right now. You can keep typing.';

  @override
  String get checkInSpeechTranscriptionUnavailable =>
      'We could not transcribe right now. You can keep typing.';

  @override
  String get checkInSaveTimeout =>
      'Your check-in was not saved. Check your connection and try again.';

  @override
  String get checkInSavedDeepReadingLater =>
      'Check-in saved. You can continue; the deep reading can be unlocked later.';

  @override
  String get checkInReminderMorningTitle => 'Gentle morning reminder';

  @override
  String get checkInReminderMorningMessage =>
      'Would you like a gentle morning reminder to care for your moment?';

  @override
  String get engagementTrailResumeTitle => 'Your trail is waiting';

  @override
  String get engagementTrailResumeBody =>
      'Take one small step in your growth today.';

  @override
  String get engagementWeeklyMirrorTitle => 'Your Weekly Mirror is ready';

  @override
  String get engagementWeeklyMirrorBody =>
      'See small signs of your growth from the last few days.';

  @override
  String get checkInReminderEnable => 'Enable reminder';

  @override
  String get checkInReminderEnabled => 'Daily reminder enabled for 08:00.';

  @override
  String get checkInReminderPermissionDenied =>
      'We could not enable the reminder without notification permission.';

  @override
  String get checkInEvolutionReminderTitle =>
      'Want to keep your growth on track?';

  @override
  String get checkInEvolutionReminderMessage =>
      'Evolua can send gentle reminders so you don’t forget your check-in, continue your trails, and revisit your Weekly Mirror.';

  @override
  String get checkInEvolutionReminderEnable => 'Enable reminders';

  @override
  String get checkInEvolutionReminderEnabled => 'Reminders enabled.';

  @override
  String get checkInEvolutionReminderPermissionDenied =>
      'No problem. You can enable reminders later in Settings.';

  @override
  String get checkInRewardConfirmTitle => 'We could not confirm the ad';

  @override
  String get checkInExtraAvailableMessage =>
      'You have already used today\'s free check-in. To record another moment, watch an ad or continue without limits with Premium.';

  @override
  String get checkInExtraUnavailableMessage =>
      'You have already used today\'s ad unlock. To record another check-in now, see Premium or come back tomorrow.';

  @override
  String get checkInExtraRewardLabel =>
      'Watching an ad unlocks one more check-in today.';

  @override
  String get checkInSavedWithCare => 'Check-in saved with care.';

  @override
  String get checkInRewardReceivedButBlocked =>
      'We received the reward, but could not unlock this check-in right now. Try again in a moment.';

  @override
  String get checkInRewardTrySaveAgain => 'Try saving again';

  @override
  String get checkInRewardWatchAd => 'Watch ad';

  @override
  String get checkInRewardTryAgain => 'Try again';

  @override
  String get checkInRewardConfirming => 'Confirming reward';

  @override
  String get checkInRewardOpeningAd => 'Opening ad';

  @override
  String get checkInRewardPremium => 'See Premium';

  @override
  String get checkInRewardNoAdAvailableTitle => 'No ad available right now';

  @override
  String get checkInRewardConfirmationInProgressTitle =>
      'Confirmation in progress';

  @override
  String get checkInRewardAdNotCompletedTitle => 'Ad not completed';

  @override
  String get checkInRewardUnlockTitle => 'Unlock another check-in today';

  @override
  String get checkInRewardLoadUnavailableMessage =>
      'We could not load an ad right now. Try again in a moment, come back tomorrow for your free check-in, or continue ad-free with Premium.';

  @override
  String get checkInRewardConfirmationPendingMessage =>
      'We received the ad completion, but we are still confirming the unlock. Try saving again in a few seconds.';

  @override
  String get checkInRewardDismissedMessage =>
      'To unlock one more check-in today, you need to complete the ad until you receive the reward.';

  @override
  String get checkInRewardConfirmedMessage => 'Ad confirmed.';

  @override
  String get checkInStopDictationTooltip => 'Stop dictation';

  @override
  String get checkInUseMicrophoneTooltip => 'Use microphone';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get errorNetwork =>
      'We could not connect right now. Check your connection and try again.';

  @override
  String get errorNoInternet =>
      'We could not connect right now. Check your internet and try again.';

  @override
  String get errorTimeout =>
      'The response took longer than expected. Try again in a moment.';

  @override
  String get errorSessionExpired =>
      'Your session expired. Sign in again to continue.';

  @override
  String get errorServerUnavailable =>
      'Evolua is temporarily unavailable. Try again in a few moments.';

  @override
  String get errorCheckInQuota =>
      'You have already used today\'s free check-in. Watch an ad, subscribe to Premium, or come back tomorrow.';

  @override
  String get errorSmartReadingUnavailable =>
      'Your check-in is saved, but we could not prepare the reading right now.';

  @override
  String get errorRewardedAdUnavailable =>
      'We could not load the ad right now. Try again in a moment.';

  @override
  String get errorUnexpected =>
      'We could not complete this right now. Try again in a moment.';

  @override
  String get errorTryAgainLater =>
      'We could not complete this right now. Try again later.';

  @override
  String get emptyDefaultTitle => 'Nothing here yet';

  @override
  String get emptyDefaultBody =>
      'When there is something new, it will appear here.';

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
  String get avatarSignatureCreatedBy => 'Created with care by Zenith IT';

  @override
  String get avatarSignatureVersion => 'Evolua v1.0.0';

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
  String get firstExperienceTitle => 'Welcome to Evolua';

  @override
  String get firstExperienceMainMessage =>
      'Let\'s start with a simple check-in. It takes less than a minute.';

  @override
  String get firstExperienceDescription =>
      'From there, Evolua prepares your intelligent reading and suggests one gentle next step for today.';

  @override
  String get firstExperienceStart => 'Start check-in';

  @override
  String get firstExperienceNotNow => 'Not now';

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
  String get homeSmartReadingGeneratingTitle => 'Generating reading...';

  @override
  String get homeSmartReadingGeneratingBody =>
      'You can keep going. We are preparing the reading for this moment.';

  @override
  String get homeSmartReadingUnavailableTitle =>
      'Reading unavailable right now';

  @override
  String get homeSmartReadingUnavailableBody =>
      'We could not generate the reading right now, but your check-in was saved.';

  @override
  String get homeFullAnalysis => 'View full analysis';

  @override
  String get homeMirrorRewardTitle =>
      'Your check-in already counts toward your Mirror';

  @override
  String get homeMirrorRewardDescription =>
      'The more you record, the more your Mirror reveals patterns.';

  @override
  String get homeMirrorRewardAnalysis => 'View analysis';

  @override
  String get homeMirrorRewardTrail => 'Continue trail';

  @override
  String get homeMirrorRewardMirror => 'View my Mirror';

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
  String get trailMyJourney => 'Current journey';

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
  String get checkInSavingLabel => 'Saving check-in...';

  @override
  String get checkInNotNow => 'Not now';

  @override
  String get checkInSavedSnack => 'Check-in saved. Continue at your pace.';

  @override
  String get checkInSavedReadingPending =>
      'Check-in saved. You can keep going, the reading will appear shortly.';

  @override
  String get checkInSavingInProgress =>
      'We are saving your check-in. Please wait a moment.';

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

  @override
  String get dailyRitualAnswerAllSteps =>
      'Answer the four steps at your own pace.';

  @override
  String get dailyRitualSavedMorning =>
      'Ritual saved. Your daily journey has a clear direction.';

  @override
  String get dailyRitualSavedEvening =>
      'Evening closing saved. Release what you do not need to carry.';

  @override
  String get dailyRitualOpenError => 'We could not open your ritual right now.';

  @override
  String get dailyRitualSaveError => 'We could not save your ritual right now.';

  @override
  String get dailyRitualMorningTitle => 'Daily Ritual';

  @override
  String get dailyRitualMorningDescription =>
      'A short pause to notice how you are, choose an intention, and define one possible small step for today.';

  @override
  String get dailyRitualMorningResultTitle => 'Your ritual for today is ready';

  @override
  String get dailyRitualEveningTitle => 'Evening Closing';

  @override
  String get dailyRitualEveningDescription =>
      'A short pause to review what felt heavy, acknowledge what was good, and release what you do not need to carry.';

  @override
  String get dailyRitualEveningResultTitle => 'Your closing for today is ready';

  @override
  String get dailyRitualDurationChip => 'Takes about 2 minutes';

  @override
  String get dailyRitualNoRightWrongChip => 'No right or wrong';

  @override
  String get dailyRitualAtYourPaceChip => 'At your pace';

  @override
  String get dailyRitualStartNow => 'Start now';

  @override
  String get dailyRitualAnswerLabel => 'Your answer';

  @override
  String get dailyRitualContinue => 'Continue';

  @override
  String get dailyRitualFinish => 'Finish';

  @override
  String get dailyRitualEmotionalState => 'Emotional state';

  @override
  String get dailyRitualDayNeed => 'Need of the day';

  @override
  String get dailyRitualChosenIntention => 'Chosen intention';

  @override
  String get dailyRitualChosenMicroAction => 'Chosen micro-action';

  @override
  String get dailyRitualBackHome => 'Back to Home';

  @override
  String get dailyRitualMorningQuestionState => 'How are you right now?';

  @override
  String get dailyRitualMorningQuestionNeed => 'What do you need most today?';

  @override
  String get dailyRitualMorningQuestionIntention =>
      'What intention do you want to carry today?';

  @override
  String get dailyRitualMorningQuestionAction =>
      'What small step can you take today?';

  @override
  String get dailyRitualEveningQuestionState => 'How are you right now?';

  @override
  String get dailyRitualEveningQuestionNeed =>
      'What do you most need to release today?';

  @override
  String get dailyRitualEveningQuestionIntention =>
      'What intention do you want to take into rest?';

  @override
  String get dailyRitualEveningQuestionAction =>
      'What small care can you offer yourself now?';

  @override
  String get careLoadingSecureAccess => 'Loading secure access...';

  @override
  String get careLoadErrorTitle => 'We could not load Evolua Care';

  @override
  String get careLoadErrorMessage =>
      'Check your connection and try again in a moment.';

  @override
  String get careRecommendationsLoading => 'Loading therapist guidance...';

  @override
  String get careRecommendationsError =>
      'We could not load therapist guidance right now.';

  @override
  String get careRecommendationsTitle => 'Therapist guidance';

  @override
  String get careRecommendationsSubtitle =>
      'Recommendations and attachments received through secure access.';

  @override
  String get careRecommendationsEmpty => 'No guidance received yet.';

  @override
  String get careTherapistFallback => 'Therapist';

  @override
  String get careAcknowledgeReading => 'Confirm reading';

  @override
  String get carePreparingAccess => 'Preparing secure access...';

  @override
  String get careShareTitle => 'Share with your therapist';

  @override
  String get careShareMessage =>
      'Generate temporary access so your therapist can view a protected report of your emotional journey.';

  @override
  String get careGenerateSecureAccess => 'Generate secure access';

  @override
  String get careExpiredTitle => 'Session expired';

  @override
  String get careExpiredMessage =>
      'The temporary access expired. Generate a new code when you are with your therapist.';

  @override
  String get careGenerateNewAccess => 'Generate new access';

  @override
  String get careRevokedTitle => 'Access revoked';

  @override
  String get careRevokedMessage =>
      'Your therapist can no longer access this shared session.';

  @override
  String get careQrMissing =>
      'For safety, generate new access to show the complete QR Code.';

  @override
  String get careTemporaryCode => 'Temporary code';

  @override
  String careExpiresAt(Object value) {
    return 'Expires at $value';
  }

  @override
  String get careCodeCopied => 'Code copied safely.';

  @override
  String get careCopyCode => 'Copy code';

  @override
  String get careFullLinkCopied => 'Complete link copied safely.';

  @override
  String get careCopyFullLink => 'Copy complete link';

  @override
  String get careRevokeAccess => 'Revoke access';

  @override
  String get careConnectedTitle => 'Connected to therapist';

  @override
  String get careActiveTitle => 'Temporary access active';

  @override
  String get careConnectedMessage =>
      'Your therapist validated access. You can revoke it whenever you want.';

  @override
  String get careActiveMessage =>
      'Show the QR Code or code to your therapist only during the session.';

  @override
  String get careHistoryLoading => 'Loading connection history...';

  @override
  String get careHistoryError =>
      'We could not load history right now. Try again later.';

  @override
  String get careHistoryTitle => 'Connection history';

  @override
  String get careHistorySubtitle =>
      'Track temporary accesses created for care sessions.';

  @override
  String get careHistoryEmpty => 'No previous connection yet.';

  @override
  String careHistoryTile(Object status, Object date) {
    return 'Session with therapist $status on $date';
  }

  @override
  String get careStatusConnected => 'connected';

  @override
  String get careStatusRevoked => 'revoked';

  @override
  String get careStatusExpired => 'expired';

  @override
  String get careStatusActive => 'active';

  @override
  String get careStatusRegistered => 'registered';
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
  String get authRegisterFallbackError =>
      'We could not create your account right now. Check your details and try again.';

  @override
  String get authRegisterEmailExistsError =>
      'This email is already registered. Sign in to your account or use another email.';

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
  String get authValidationEmailRequired => 'Enter your email.';

  @override
  String authValidationEmailMaxLength(Object maxLength) {
    return 'Use an email with up to $maxLength characters.';
  }

  @override
  String get authValidationEmailInvalid => 'Use a valid email.';

  @override
  String get authValidationPasswordRequired => 'Enter your password.';

  @override
  String authValidationPasswordMinLength(Object minLength) {
    return 'The password must have at least $minLength characters.';
  }

  @override
  String authValidationPasswordMaxLength(Object maxLength) {
    return 'Use a password with up to $maxLength characters.';
  }

  @override
  String get authValidationConfirmPasswordRequired => 'Confirm your password.';

  @override
  String get authValidationPasswordsDoNotMatch => 'The passwords do not match.';

  @override
  String get authValidationDisplayNameRequired => 'Enter your name.';

  @override
  String authValidationDisplayNameMinLength(Object minLength) {
    return 'Enter a name with at least $minLength characters.';
  }

  @override
  String authValidationDisplayNameMaxLength(Object maxLength) {
    return 'Enter a name with up to $maxLength characters.';
  }

  @override
  String get authValidationDisplayNameLettersOnly =>
      'Use only letters, spaces, and accents in the name.';

  @override
  String get authValidationBirthDateRequired => 'Enter your birth date.';

  @override
  String get authValidationBirthDateFormat =>
      'Use a valid date in dd/mm/yyyy format.';

  @override
  String get authValidationBirthDateInvalid => 'Enter a valid birth date.';

  @override
  String authValidationMinimumAge(Object minimumAge) {
    return 'You must be at least $minimumAge years old to create an account.';
  }

  @override
  String get authValidationGenderRequired => 'Select a gender option.';

  @override
  String get authValidationCustomGenderRequired => 'Enter how you identify.';

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
  String get commonSaving => 'Saving...';

  @override
  String get commonSending => 'Sending...';

  @override
  String get commonSend => 'Send';

  @override
  String get commonRetry => 'Try again';

  @override
  String get routerBootErrorTitle => 'We could not start Evolua right now.';

  @override
  String get routerBootErrorBody =>
      'Check your connection and try again in a moment.';

  @override
  String get routerNotFoundTitle => 'We could not find this page.';

  @override
  String get routerNotFoundBody =>
      'The link may have changed or may no longer be available.';

  @override
  String get routerBackToEvolua => 'Back to Evolua';

  @override
  String get dashboardCareRitualReceived =>
      'New ritual received from your therapist.';

  @override
  String get dashboardCareGuidanceReceived =>
      'New guidance from your therapist.';

  @override
  String get dashboardEmailVerificationSent =>
      'We sent a new confirmation email.';

  @override
  String get dashboardEmailVerificationResendError =>
      'We could not resend it right now. Try again in a moment.';

  @override
  String get dashboardEmailVerificationConfirmed =>
      'Email confirmed. Thank you!';

  @override
  String get dashboardEmailVerificationStillPending =>
      'We have not detected the confirmation yet. Check your email and try again.';

  @override
  String get appUpdateRecommendedTitle => 'New version available';

  @override
  String get appUpdateRecommendedFallbackMessage =>
      'Update Evolua to receive improvements, fixes, and a more stable experience.';

  @override
  String get appUpdateRequiredTitle => 'Update required';

  @override
  String get appUpdateRequiredFallbackMessage =>
      'This version of Evolua is no longer compatible with important security and stability improvements. Update to continue.';

  @override
  String get appUpdateDismiss => 'Not now';

  @override
  String get appUpdateAction => 'Update';

  @override
  String get appUpdateGooglePlayAction => 'Update on Google Play';

  @override
  String get dashboardCareRecommendationReceived =>
      'New guidance from your therapist.';

  @override
  String get dashboardMainNavigationSemantic => 'Main navigation';

  @override
  String get dashboardSidebarMenuSemantic => 'Side menu';

  @override
  String get dashboardAuthenticatedHeaderSemantic =>
      'Authenticated area header';

  @override
  String get dashboardMentorTitle => 'Evolua Mentor';

  @override
  String get dashboardEmailVerificationNotice =>
      'Confirm your email to keep your account safer.';

  @override
  String get dashboardEmailVerificationResend => 'Resend email';

  @override
  String get dashboardEmailVerificationRefreshing => 'Updating...';

  @override
  String get dashboardEmailVerificationAlreadyConfirmed =>
      'I already confirmed';

  @override
  String get dashboardCheckingCheckIn => 'Checking check-in';

  @override
  String get accountOpenMenuTooltip => 'Open account menu';

  @override
  String get accountConnectTherapist => 'Connect Therapist';

  @override
  String get accountHelpSupport => 'Help and support';

  @override
  String get accountDisplayAccessibility => 'Display and accessibility';

  @override
  String get accountFeedback => 'Give feedback';

  @override
  String get accountFallbackEmail => 'you@evolua.app';

  @override
  String get commonUnderstood => 'Got it';

  @override
  String get checkInMicrophoneUnavailable =>
      'The microphone is not available right now. You can keep typing.';

  @override
  String get checkInSpeechTranscriptionUnavailable =>
      'We could not transcribe right now. You can keep typing.';

  @override
  String get checkInSaveTimeout =>
      'Your check-in was not saved. Check your connection and try again.';

  @override
  String get checkInSavedDeepReadingLater =>
      'Check-in saved. You can continue; the deep reading can be unlocked later.';

  @override
  String get checkInReminderMorningTitle => 'Gentle morning reminder';

  @override
  String get checkInReminderMorningMessage =>
      'Would you like a gentle morning reminder to care for your moment?';

  @override
  String get engagementTrailResumeTitle => 'Your trail is waiting';

  @override
  String get engagementTrailResumeBody =>
      'Take one small step in your growth today.';

  @override
  String get engagementWeeklyMirrorTitle => 'Your Weekly Mirror is ready';

  @override
  String get engagementWeeklyMirrorBody =>
      'See small signs of your growth from the last few days.';

  @override
  String get checkInReminderEnable => 'Enable reminder';

  @override
  String get checkInReminderEnabled => 'Daily reminder enabled for 08:00.';

  @override
  String get checkInReminderPermissionDenied =>
      'We could not enable the reminder without notification permission.';

  @override
  String get checkInEvolutionReminderTitle =>
      'Want to keep your growth on track?';

  @override
  String get checkInEvolutionReminderMessage =>
      'Evolua can send gentle reminders so you don’t forget your check-in, continue your trails, and revisit your Weekly Mirror.';

  @override
  String get checkInEvolutionReminderEnable => 'Enable reminders';

  @override
  String get checkInEvolutionReminderEnabled => 'Reminders enabled.';

  @override
  String get checkInEvolutionReminderPermissionDenied =>
      'No problem. You can enable reminders later in Settings.';

  @override
  String get checkInRewardConfirmTitle => 'We could not confirm the ad';

  @override
  String get checkInExtraAvailableMessage =>
      'You have already used today\'s free check-in. To record another moment, watch an ad or continue without limits with Premium.';

  @override
  String get checkInExtraUnavailableMessage =>
      'You have already used today\'s ad unlock. To record another check-in now, see Premium or come back tomorrow.';

  @override
  String get checkInExtraRewardLabel =>
      'Watching an ad unlocks one more check-in today.';

  @override
  String get checkInSavedWithCare => 'Check-in saved with care.';

  @override
  String get checkInRewardReceivedButBlocked =>
      'We received the reward, but could not unlock this check-in right now. Try again in a moment.';

  @override
  String get checkInRewardTrySaveAgain => 'Try saving again';

  @override
  String get checkInRewardWatchAd => 'Watch ad';

  @override
  String get checkInRewardTryAgain => 'Try again';

  @override
  String get checkInRewardConfirming => 'Confirming reward';

  @override
  String get checkInRewardOpeningAd => 'Opening ad';

  @override
  String get checkInRewardPremium => 'See Premium';

  @override
  String get checkInRewardNoAdAvailableTitle => 'No ad available right now';

  @override
  String get checkInRewardConfirmationInProgressTitle =>
      'Confirmation in progress';

  @override
  String get checkInRewardAdNotCompletedTitle => 'Ad not completed';

  @override
  String get checkInRewardUnlockTitle => 'Unlock another check-in today';

  @override
  String get checkInRewardLoadUnavailableMessage =>
      'We could not load an ad right now. Try again in a moment, come back tomorrow for your free check-in, or continue ad-free with Premium.';

  @override
  String get checkInRewardConfirmationPendingMessage =>
      'We received the ad completion, but we are still confirming the unlock. Try saving again in a few seconds.';

  @override
  String get checkInRewardDismissedMessage =>
      'To unlock one more check-in today, you need to complete the ad until you receive the reward.';

  @override
  String get checkInRewardConfirmedMessage => 'Ad confirmed.';

  @override
  String get checkInStopDictationTooltip => 'Stop dictation';

  @override
  String get checkInUseMicrophoneTooltip => 'Use microphone';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get errorNetwork =>
      'We could not connect right now. Check your connection and try again.';

  @override
  String get errorNoInternet =>
      'We could not connect right now. Check your internet and try again.';

  @override
  String get errorTimeout =>
      'The response took longer than expected. Try again in a moment.';

  @override
  String get errorSessionExpired =>
      'Your session expired. Sign in again to continue.';

  @override
  String get errorServerUnavailable =>
      'Evolua is temporarily unavailable. Try again in a few moments.';

  @override
  String get errorCheckInQuota =>
      'You have already used today\'s free check-in. Watch an ad, subscribe to Premium, or come back tomorrow.';

  @override
  String get errorSmartReadingUnavailable =>
      'Your check-in is saved, but we could not prepare the reading right now.';

  @override
  String get errorRewardedAdUnavailable =>
      'We could not load the ad right now. Try again in a moment.';

  @override
  String get errorUnexpected =>
      'We could not complete this right now. Try again in a moment.';

  @override
  String get errorTryAgainLater =>
      'We could not complete this right now. Try again later.';

  @override
  String get emptyDefaultTitle => 'Nothing here yet';

  @override
  String get emptyDefaultBody =>
      'When there is something new, it will appear here.';

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
  String get avatarSignatureCreatedBy => 'Created with care by Zenith IT';

  @override
  String get avatarSignatureVersion => 'Evolua v1.0.0';

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
  String get firstExperienceTitle => 'Welcome to Evolua';

  @override
  String get firstExperienceMainMessage =>
      'Let\'s start with a simple check-in. It takes less than a minute.';

  @override
  String get firstExperienceDescription =>
      'From there, Evolua prepares your intelligent reading and suggests one gentle next step for today.';

  @override
  String get firstExperienceStart => 'Start check-in';

  @override
  String get firstExperienceNotNow => 'Not now';

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
  String get homeSmartReadingGeneratingTitle => 'Generating reading...';

  @override
  String get homeSmartReadingGeneratingBody =>
      'You can keep going. We are preparing the reading for this moment.';

  @override
  String get homeSmartReadingUnavailableTitle =>
      'Reading unavailable right now';

  @override
  String get homeSmartReadingUnavailableBody =>
      'We could not generate the reading right now, but your check-in was saved.';

  @override
  String get homeFullAnalysis => 'View full analysis';

  @override
  String get homeMirrorRewardTitle =>
      'Your check-in already counts toward your Mirror';

  @override
  String get homeMirrorRewardDescription =>
      'The more you record, the more your Mirror reveals patterns.';

  @override
  String get homeMirrorRewardAnalysis => 'View analysis';

  @override
  String get homeMirrorRewardTrail => 'Continue trail';

  @override
  String get homeMirrorRewardMirror => 'View my Mirror';

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
  String get trailMyJourney => 'Current journey';

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
  String get checkInSavingLabel => 'Saving check-in...';

  @override
  String get checkInNotNow => 'Not now';

  @override
  String get checkInSavedSnack => 'Check-in saved. Continue at your pace.';

  @override
  String get checkInSavedReadingPending =>
      'Check-in saved. You can keep going, the reading will appear shortly.';

  @override
  String get checkInSavingInProgress =>
      'We are saving your check-in. Please wait a moment.';

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

  @override
  String get dailyRitualAnswerAllSteps =>
      'Answer the four steps at your own pace.';

  @override
  String get dailyRitualSavedMorning =>
      'Ritual saved. Your daily journey has a clear direction.';

  @override
  String get dailyRitualSavedEvening =>
      'Evening closing saved. Release what you do not need to carry.';

  @override
  String get dailyRitualOpenError => 'We could not open your ritual right now.';

  @override
  String get dailyRitualSaveError => 'We could not save your ritual right now.';

  @override
  String get dailyRitualMorningTitle => 'Daily Ritual';

  @override
  String get dailyRitualMorningDescription =>
      'A short pause to notice how you are, choose an intention, and define one possible small step for today.';

  @override
  String get dailyRitualMorningResultTitle => 'Your ritual for today is ready';

  @override
  String get dailyRitualEveningTitle => 'Evening Closing';

  @override
  String get dailyRitualEveningDescription =>
      'A short pause to review what felt heavy, acknowledge what was good, and release what you do not need to carry.';

  @override
  String get dailyRitualEveningResultTitle => 'Your closing for today is ready';

  @override
  String get dailyRitualDurationChip => 'Takes about 2 minutes';

  @override
  String get dailyRitualNoRightWrongChip => 'No right or wrong';

  @override
  String get dailyRitualAtYourPaceChip => 'At your pace';

  @override
  String get dailyRitualStartNow => 'Start now';

  @override
  String get dailyRitualAnswerLabel => 'Your answer';

  @override
  String get dailyRitualContinue => 'Continue';

  @override
  String get dailyRitualFinish => 'Finish';

  @override
  String get dailyRitualEmotionalState => 'Emotional state';

  @override
  String get dailyRitualDayNeed => 'Need of the day';

  @override
  String get dailyRitualChosenIntention => 'Chosen intention';

  @override
  String get dailyRitualChosenMicroAction => 'Chosen micro-action';

  @override
  String get dailyRitualBackHome => 'Back to Home';

  @override
  String get dailyRitualMorningQuestionState => 'How are you right now?';

  @override
  String get dailyRitualMorningQuestionNeed => 'What do you need most today?';

  @override
  String get dailyRitualMorningQuestionIntention =>
      'What intention do you want to carry today?';

  @override
  String get dailyRitualMorningQuestionAction =>
      'What small step can you take today?';

  @override
  String get dailyRitualEveningQuestionState => 'How are you right now?';

  @override
  String get dailyRitualEveningQuestionNeed =>
      'What do you most need to release today?';

  @override
  String get dailyRitualEveningQuestionIntention =>
      'What intention do you want to take into rest?';

  @override
  String get dailyRitualEveningQuestionAction =>
      'What small care can you offer yourself now?';

  @override
  String get careLoadingSecureAccess => 'Loading secure access...';

  @override
  String get careLoadErrorTitle => 'We could not load Evolua Care';

  @override
  String get careLoadErrorMessage =>
      'Check your connection and try again in a moment.';

  @override
  String get careRecommendationsLoading => 'Loading therapist guidance...';

  @override
  String get careRecommendationsError =>
      'We could not load therapist guidance right now.';

  @override
  String get careRecommendationsTitle => 'Therapist guidance';

  @override
  String get careRecommendationsSubtitle =>
      'Recommendations and attachments received through secure access.';

  @override
  String get careRecommendationsEmpty => 'No guidance received yet.';

  @override
  String get careTherapistFallback => 'Therapist';

  @override
  String get careAcknowledgeReading => 'Confirm reading';

  @override
  String get carePreparingAccess => 'Preparing secure access...';

  @override
  String get careShareTitle => 'Share with your therapist';

  @override
  String get careShareMessage =>
      'Generate temporary access so your therapist can view a protected report of your emotional journey.';

  @override
  String get careGenerateSecureAccess => 'Generate secure access';

  @override
  String get careExpiredTitle => 'Session expired';

  @override
  String get careExpiredMessage =>
      'The temporary access expired. Generate a new code when you are with your therapist.';

  @override
  String get careGenerateNewAccess => 'Generate new access';

  @override
  String get careRevokedTitle => 'Access revoked';

  @override
  String get careRevokedMessage =>
      'Your therapist can no longer access this shared session.';

  @override
  String get careQrMissing =>
      'For safety, generate new access to show the complete QR Code.';

  @override
  String get careTemporaryCode => 'Temporary code';

  @override
  String careExpiresAt(Object value) {
    return 'Expires at $value';
  }

  @override
  String get careCodeCopied => 'Code copied safely.';

  @override
  String get careCopyCode => 'Copy code';

  @override
  String get careFullLinkCopied => 'Complete link copied safely.';

  @override
  String get careCopyFullLink => 'Copy complete link';

  @override
  String get careRevokeAccess => 'Revoke access';

  @override
  String get careConnectedTitle => 'Connected to therapist';

  @override
  String get careActiveTitle => 'Temporary access active';

  @override
  String get careConnectedMessage =>
      'Your therapist validated access. You can revoke it whenever you want.';

  @override
  String get careActiveMessage =>
      'Show the QR Code or code to your therapist only during the session.';

  @override
  String get careHistoryLoading => 'Loading connection history...';

  @override
  String get careHistoryError =>
      'We could not load history right now. Try again later.';

  @override
  String get careHistoryTitle => 'Connection history';

  @override
  String get careHistorySubtitle =>
      'Track temporary accesses created for care sessions.';

  @override
  String get careHistoryEmpty => 'No previous connection yet.';

  @override
  String careHistoryTile(Object status, Object date) {
    return 'Session with therapist $status on $date';
  }

  @override
  String get careStatusConnected => 'connected';

  @override
  String get careStatusRevoked => 'revoked';

  @override
  String get careStatusExpired => 'expired';

  @override
  String get careStatusActive => 'active';

  @override
  String get careStatusRegistered => 'registered';
}

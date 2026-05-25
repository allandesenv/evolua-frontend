import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('pt', 'BR'),
    Locale('en', 'US'),
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Evolua'**
  String get appTitle;

  /// No description provided for @authFormSemanticLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Formulário de autenticação'**
  String get authFormSemanticLabel;

  /// No description provided for @authLoginTab.
  ///
  /// In pt_BR, this message translates to:
  /// **'Entrar'**
  String get authLoginTab;

  /// No description provided for @authRegisterTab.
  ///
  /// In pt_BR, this message translates to:
  /// **'Criar conta'**
  String get authRegisterTab;

  /// No description provided for @authGoogleContinue.
  ///
  /// In pt_BR, this message translates to:
  /// **'Continuar com Google'**
  String get authGoogleContinue;

  /// No description provided for @authLoginFallbackError.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não foi possível autenticar. Revise os dados e tente novamente.'**
  String get authLoginFallbackError;

  /// No description provided for @authGoogleStartError.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não foi possível iniciar o login com Google. Tente novamente.'**
  String get authGoogleStartError;

  /// No description provided for @authDisplayNameLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nome'**
  String get authDisplayNameLabel;

  /// No description provided for @authDisplayNameHint.
  ///
  /// In pt_BR, this message translates to:
  /// **'Como você quer ser chamado'**
  String get authDisplayNameHint;

  /// No description provided for @authBirthDateLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Data de nascimento'**
  String get authBirthDateLabel;

  /// No description provided for @authBirthDateEmpty.
  ///
  /// In pt_BR, this message translates to:
  /// **'Selecione sua data'**
  String get authBirthDateEmpty;

  /// No description provided for @authBirthDateHint.
  ///
  /// In pt_BR, this message translates to:
  /// **'dd/mm/aaaa'**
  String get authBirthDateHint;

  /// No description provided for @authBirthDateOpenPicker.
  ///
  /// In pt_BR, this message translates to:
  /// **'Abrir calendário'**
  String get authBirthDateOpenPicker;

  /// No description provided for @authGenderLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Gênero'**
  String get authGenderLabel;

  /// No description provided for @authGenderMale.
  ///
  /// In pt_BR, this message translates to:
  /// **'Masculino'**
  String get authGenderMale;

  /// No description provided for @authGenderFemale.
  ///
  /// In pt_BR, this message translates to:
  /// **'Feminino'**
  String get authGenderFemale;

  /// No description provided for @authGenderPreferNotToSay.
  ///
  /// In pt_BR, this message translates to:
  /// **'Prefiro não informar'**
  String get authGenderPreferNotToSay;

  /// No description provided for @authGenderCustom.
  ///
  /// In pt_BR, this message translates to:
  /// **'Personalizado'**
  String get authGenderCustom;

  /// No description provided for @authCustomGenderLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Como você se identifica'**
  String get authCustomGenderLabel;

  /// No description provided for @authCustomGenderHint.
  ///
  /// In pt_BR, this message translates to:
  /// **'Escreva do seu jeito'**
  String get authCustomGenderHint;

  /// No description provided for @authEmailLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'E-mail'**
  String get authEmailLabel;

  /// No description provided for @authEmailHint.
  ///
  /// In pt_BR, this message translates to:
  /// **'voce@evolua.app'**
  String get authEmailHint;

  /// No description provided for @authPasswordLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Senha'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordHint.
  ///
  /// In pt_BR, this message translates to:
  /// **'De 6 a 72 caracteres'**
  String get authPasswordHint;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Confirmar senha'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authConfirmPasswordHint.
  ///
  /// In pt_BR, this message translates to:
  /// **'Digite a senha novamente'**
  String get authConfirmPasswordHint;

  /// No description provided for @authPasswordRules.
  ///
  /// In pt_BR, this message translates to:
  /// **'Use de 6 a 72 caracteres. Você pode usar letras, números e símbolos.'**
  String get authPasswordRules;

  /// No description provided for @authHidePassword.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ocultar senha'**
  String get authHidePassword;

  /// No description provided for @authShowPassword.
  ///
  /// In pt_BR, this message translates to:
  /// **'Mostrar senha'**
  String get authShowPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In pt_BR, this message translates to:
  /// **'Esqueci minha senha'**
  String get authForgotPassword;

  /// No description provided for @authForgotPasswordTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Recuperar senha'**
  String get authForgotPasswordTitle;

  /// No description provided for @authForgotPasswordBody.
  ///
  /// In pt_BR, this message translates to:
  /// **'Informe seu e-mail de acesso. Se ele estiver cadastrado, enviaremos um link para criar uma nova senha.'**
  String get authForgotPasswordBody;

  /// No description provided for @authForgotPasswordSuccess.
  ///
  /// In pt_BR, this message translates to:
  /// **'Se este e-mail estiver cadastrado, enviaremos as instruções de recuperação.'**
  String get authForgotPasswordSuccess;

  /// No description provided for @authForgotPasswordError.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não foi possível solicitar a recuperação agora.'**
  String get authForgotPasswordError;

  /// No description provided for @authForgotPasswordTimeout.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não conseguimos confirmar o envio agora. Tente novamente em instantes.'**
  String get authForgotPasswordTimeout;

  /// No description provided for @commonCancel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In pt_BR, this message translates to:
  /// **'Fechar'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In pt_BR, this message translates to:
  /// **'Salvar'**
  String get commonSave;

  /// No description provided for @commonLoading.
  ///
  /// In pt_BR, this message translates to:
  /// **'Carregando...'**
  String get commonLoading;

  /// No description provided for @commonSend.
  ///
  /// In pt_BR, this message translates to:
  /// **'Enviar'**
  String get commonSend;

  /// No description provided for @commonRetry.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tentar novamente'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In pt_BR, this message translates to:
  /// **'Atualizar'**
  String get commonRefresh;

  /// No description provided for @commonBack.
  ///
  /// In pt_BR, this message translates to:
  /// **'Voltar'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In pt_BR, this message translates to:
  /// **'Próximo'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In pt_BR, this message translates to:
  /// **'Anterior'**
  String get commonPrevious;

  /// No description provided for @authSendLink.
  ///
  /// In pt_BR, this message translates to:
  /// **'Enviar link'**
  String get authSendLink;

  /// No description provided for @authResendLink.
  ///
  /// In pt_BR, this message translates to:
  /// **'Reenviar link'**
  String get authResendLink;

  /// No description provided for @authSendingLink.
  ///
  /// In pt_BR, this message translates to:
  /// **'Enviando...'**
  String get authSendingLink;

  /// No description provided for @resetPasswordSemanticLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Redefinir senha'**
  String get resetPasswordSemanticLabel;

  /// No description provided for @resetPasswordInvalidLink.
  ///
  /// In pt_BR, this message translates to:
  /// **'Link de recuperação inválido.'**
  String get resetPasswordInvalidLink;

  /// No description provided for @resetPasswordCompletedSnack.
  ///
  /// In pt_BR, this message translates to:
  /// **'Senha redefinida. Você já pode entrar.'**
  String get resetPasswordCompletedSnack;

  /// No description provided for @resetPasswordError.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não foi possível redefinir sua senha.'**
  String get resetPasswordError;

  /// No description provided for @resetPasswordCreateTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Criar nova senha'**
  String get resetPasswordCreateTitle;

  /// No description provided for @resetPasswordCreateBody.
  ///
  /// In pt_BR, this message translates to:
  /// **'Escolha uma senha com ao menos 6 caracteres para voltar ao Evolua.'**
  String get resetPasswordCreateBody;

  /// No description provided for @resetPasswordNewLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Nova senha'**
  String get resetPasswordNewLabel;

  /// No description provided for @resetPasswordConfirmLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Confirmar nova senha'**
  String get resetPasswordConfirmLabel;

  /// No description provided for @resetPasswordMismatch.
  ///
  /// In pt_BR, this message translates to:
  /// **'As senhas não conferem.'**
  String get resetPasswordMismatch;

  /// No description provided for @resetPasswordSubmit.
  ///
  /// In pt_BR, this message translates to:
  /// **'Redefinir senha'**
  String get resetPasswordSubmit;

  /// No description provided for @resetPasswordBackToLogin.
  ///
  /// In pt_BR, this message translates to:
  /// **'Voltar para entrar'**
  String get resetPasswordBackToLogin;

  /// No description provided for @resetPasswordSuccessTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Senha redefinida'**
  String get resetPasswordSuccessTitle;

  /// No description provided for @resetPasswordSuccessBody.
  ///
  /// In pt_BR, this message translates to:
  /// **'Agora você pode entrar usando sua nova senha.'**
  String get resetPasswordSuccessBody;

  /// No description provided for @authHeroTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Continue sua jornada'**
  String get authHeroTitle;

  /// No description provided for @authHeroSubtitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Acesse seu espaço de autoconhecimento em poucos segundos.'**
  String get authHeroSubtitle;

  /// No description provided for @authHeroQuickCheckIn.
  ///
  /// In pt_BR, this message translates to:
  /// **'Check-in rápido'**
  String get authHeroQuickCheckIn;

  /// No description provided for @authHeroShortTrails.
  ///
  /// In pt_BR, this message translates to:
  /// **'Trilhas curtas'**
  String get authHeroShortTrails;

  /// No description provided for @authHeroReflections.
  ///
  /// In pt_BR, this message translates to:
  /// **'Reflexões do momento'**
  String get authHeroReflections;

  /// No description provided for @navHome.
  ///
  /// In pt_BR, this message translates to:
  /// **'Início'**
  String get navHome;

  /// No description provided for @navTrails.
  ///
  /// In pt_BR, this message translates to:
  /// **'Trilhas'**
  String get navTrails;

  /// No description provided for @navSpaces.
  ///
  /// In pt_BR, this message translates to:
  /// **'Espaços'**
  String get navSpaces;

  /// No description provided for @navMirror.
  ///
  /// In pt_BR, this message translates to:
  /// **'Espelho'**
  String get navMirror;

  /// No description provided for @navAdminPanel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Painel Admin'**
  String get navAdminPanel;

  /// No description provided for @navProfile.
  ///
  /// In pt_BR, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @avatarFutureMessages.
  ///
  /// In pt_BR, this message translates to:
  /// **'Mensagens para o futuro'**
  String get avatarFutureMessages;

  /// No description provided for @avatarPlans.
  ///
  /// In pt_BR, this message translates to:
  /// **'Planos e assinaturas'**
  String get avatarPlans;

  /// No description provided for @avatarEvolutionMirror.
  ///
  /// In pt_BR, this message translates to:
  /// **'Espelho da Evolução'**
  String get avatarEvolutionMirror;

  /// No description provided for @avatarLogout.
  ///
  /// In pt_BR, this message translates to:
  /// **'Sair'**
  String get avatarLogout;

  /// No description provided for @languageSectionTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Idioma'**
  String get languageSectionTitle;

  /// No description provided for @languageSectionSubtitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Escolha como o Evolua deve aparecer para você.'**
  String get languageSectionSubtitle;

  /// No description provided for @languagePortuguese.
  ///
  /// In pt_BR, this message translates to:
  /// **'Português (Brasil)'**
  String get languagePortuguese;

  /// No description provided for @languageEnglish.
  ///
  /// In pt_BR, this message translates to:
  /// **'English (US)'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In pt_BR, this message translates to:
  /// **'Usar idioma do sistema'**
  String get languageSystem;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Configurações e privacidade'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPreferencesSaved.
  ///
  /// In pt_BR, this message translates to:
  /// **'Preferências salvas com segurança.'**
  String get settingsPreferencesSaved;

  /// No description provided for @settingsVisualPreferencesSaved.
  ///
  /// In pt_BR, this message translates to:
  /// **'Preferências visuais salvas com conforto.'**
  String get settingsVisualPreferencesSaved;

  /// No description provided for @homeDailyMorningTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Bom dia, {name}'**
  String homeDailyMorningTitle(Object name);

  /// No description provided for @homeDailyMorningTitleNoName.
  ///
  /// In pt_BR, this message translates to:
  /// **'Bom dia'**
  String get homeDailyMorningTitleNoName;

  /// No description provided for @homeDailyMorningBody.
  ///
  /// In pt_BR, this message translates to:
  /// **'Comece o dia com presença. Escolha uma intenção simples e uma microação possível.'**
  String get homeDailyMorningBody;

  /// No description provided for @homeDailyMorningPrimary.
  ///
  /// In pt_BR, this message translates to:
  /// **'Iniciar Ritual do Dia'**
  String get homeDailyMorningPrimary;

  /// No description provided for @homeDailyDayTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Como está seu dia até aqui?'**
  String get homeDailyDayTitle;

  /// No description provided for @homeDailyDayBody.
  ///
  /// In pt_BR, this message translates to:
  /// **'Faça uma pausa curta para perceber seu estado e escolher o próximo passo.'**
  String get homeDailyDayBody;

  /// No description provided for @homeDailyDayPrimary.
  ///
  /// In pt_BR, this message translates to:
  /// **'Fazer check-in'**
  String get homeDailyDayPrimary;

  /// No description provided for @homeDailyDaySecondary.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ver próximo passo'**
  String get homeDailyDaySecondary;

  /// No description provided for @homeDailyEveningTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Vamos fechar o dia?'**
  String get homeDailyEveningTitle;

  /// No description provided for @homeDailyEveningBody.
  ///
  /// In pt_BR, this message translates to:
  /// **'Revise o que pesou, reconheça o que foi bom e solte o que não precisa carregar.'**
  String get homeDailyEveningBody;

  /// No description provided for @homeDailyEveningPrimary.
  ///
  /// In pt_BR, this message translates to:
  /// **'Fazer Fechamento do Dia'**
  String get homeDailyEveningPrimary;

  /// No description provided for @homeDailyEveningSecondary.
  ///
  /// In pt_BR, this message translates to:
  /// **'Escrever reflexão'**
  String get homeDailyEveningSecondary;

  /// No description provided for @homeDailyRitualDone.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ritual do Dia concluído'**
  String get homeDailyRitualDone;

  /// No description provided for @homeDailyClosingDone.
  ///
  /// In pt_BR, this message translates to:
  /// **'Fechamento do Dia concluído'**
  String get homeDailyClosingDone;

  /// No description provided for @homeDailyViewRitual.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ver meu ritual'**
  String get homeDailyViewRitual;

  /// No description provided for @homeFutureLetter.
  ///
  /// In pt_BR, this message translates to:
  /// **'Carta para o futuro'**
  String get homeFutureLetter;

  /// No description provided for @homeRecentReflection.
  ///
  /// In pt_BR, this message translates to:
  /// **'Reflexão recente'**
  String get homeRecentReflection;

  /// No description provided for @homeQuickInsight.
  ///
  /// In pt_BR, this message translates to:
  /// **'Insight rápido'**
  String get homeQuickInsight;

  /// No description provided for @homeEvolutionMilestone.
  ///
  /// In pt_BR, this message translates to:
  /// **'Marco de evolução'**
  String get homeEvolutionMilestone;

  /// No description provided for @homeIntelligentReadingEyebrow.
  ///
  /// In pt_BR, this message translates to:
  /// **'O que isso significa?'**
  String get homeIntelligentReadingEyebrow;

  /// No description provided for @homeIntelligentReadingTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Leitura inteligente'**
  String get homeIntelligentReadingTitle;

  /// No description provided for @homeIntelligentReadingEmpty.
  ///
  /// In pt_BR, this message translates to:
  /// **'Depois do próximo check-in, a IA resume o momento e transforma a leitura em uma ação simples.'**
  String get homeIntelligentReadingEmpty;

  /// No description provided for @homeFullAnalysis.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ver análise completa'**
  String get homeFullAnalysis;

  /// No description provided for @homeEnergyBullet.
  ///
  /// In pt_BR, this message translates to:
  /// **'Energia: {value}/10'**
  String homeEnergyBullet(Object value);

  /// No description provided for @homeStateBullet.
  ///
  /// In pt_BR, this message translates to:
  /// **'Estado: {value}'**
  String homeStateBullet(Object value);

  /// No description provided for @homeBestResponseBullet.
  ///
  /// In pt_BR, this message translates to:
  /// **'Melhor resposta agora: {value}'**
  String homeBestResponseBullet(Object value);

  /// No description provided for @trailCatalog.
  ///
  /// In pt_BR, this message translates to:
  /// **'Catálogo'**
  String get trailCatalog;

  /// No description provided for @trailMyJourney.
  ///
  /// In pt_BR, this message translates to:
  /// **'Jornada atual'**
  String get trailMyJourney;

  /// No description provided for @trailStart.
  ///
  /// In pt_BR, this message translates to:
  /// **'Iniciar trilha'**
  String get trailStart;

  /// No description provided for @trailCompleteJourney.
  ///
  /// In pt_BR, this message translates to:
  /// **'Jornada completa'**
  String get trailCompleteJourney;

  /// No description provided for @trailViewCatalog.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ver catálogo'**
  String get trailViewCatalog;

  /// No description provided for @trailNoActiveJourney.
  ///
  /// In pt_BR, this message translates to:
  /// **'Sem jornada ativa.'**
  String get trailNoActiveJourney;

  /// No description provided for @trailVideo.
  ///
  /// In pt_BR, this message translates to:
  /// **'Vídeo'**
  String get trailVideo;

  /// No description provided for @trailListen.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ouvir'**
  String get trailListen;

  /// No description provided for @trailPause.
  ///
  /// In pt_BR, this message translates to:
  /// **'Pausar'**
  String get trailPause;

  /// No description provided for @trailStop.
  ///
  /// In pt_BR, this message translates to:
  /// **'Parar'**
  String get trailStop;

  /// No description provided for @trailFullscreen.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tela cheia'**
  String get trailFullscreen;

  /// No description provided for @trailSpeed.
  ///
  /// In pt_BR, this message translates to:
  /// **'Velocidade'**
  String get trailSpeed;

  /// No description provided for @trailVideoUnavailable.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não foi possível preparar este vídeo.'**
  String get trailVideoUnavailable;

  /// No description provided for @adminTrailsTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Admin de trilhas'**
  String get adminTrailsTitle;

  /// No description provided for @adminNotificationsTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Admin de notificações'**
  String get adminNotificationsTitle;

  /// No description provided for @spacesFeatured.
  ///
  /// In pt_BR, this message translates to:
  /// **'Em destaque'**
  String get spacesFeatured;

  /// No description provided for @spacesReflections.
  ///
  /// In pt_BR, this message translates to:
  /// **'Reflexões'**
  String get spacesReflections;

  /// No description provided for @spacesMine.
  ///
  /// In pt_BR, this message translates to:
  /// **'Meus'**
  String get spacesMine;

  /// No description provided for @futureMessagesTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Mensagens para o futuro'**
  String get futureMessagesTitle;

  /// No description provided for @mirrorTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Espelho da Evolução'**
  String get mirrorTitle;

  /// No description provided for @profileChangePhoto.
  ///
  /// In pt_BR, this message translates to:
  /// **'Trocar foto'**
  String get profileChangePhoto;

  /// No description provided for @profileUpdate.
  ///
  /// In pt_BR, this message translates to:
  /// **'Atualizar'**
  String get profileUpdate;

  /// No description provided for @notificationsTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Notificações'**
  String get notificationsTitle;

  /// No description provided for @plansTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Planos e assinaturas'**
  String get plansTitle;

  /// No description provided for @checkInTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Check-in'**
  String get checkInTitle;

  /// No description provided for @checkInSemanticLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Check-in do dia'**
  String get checkInSemanticLabel;

  /// No description provided for @checkInEyebrow.
  ///
  /// In pt_BR, this message translates to:
  /// **'Como estou?'**
  String get checkInEyebrow;

  /// No description provided for @checkInPromptTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Comece pelo seu estado agora'**
  String get checkInPromptTitle;

  /// No description provided for @checkInPromptSubtitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Um check-in curto já dá contexto para o seu registro breve do dia.'**
  String get checkInPromptSubtitle;

  /// No description provided for @checkInMoreStatesTooltip.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ver mais estados'**
  String get checkInMoreStatesTooltip;

  /// No description provided for @checkInMoreStates.
  ///
  /// In pt_BR, this message translates to:
  /// **'Mais estados'**
  String get checkInMoreStates;

  /// No description provided for @checkInSelectedState.
  ///
  /// In pt_BR, this message translates to:
  /// **'Estado selecionado: {state}'**
  String checkInSelectedState(Object state);

  /// No description provided for @checkInOtherMoodLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Descreva com suas palavras'**
  String get checkInOtherMoodLabel;

  /// No description provided for @checkInOtherMoodHint.
  ///
  /// In pt_BR, this message translates to:
  /// **'Opcional: escreva como você está se sentindo'**
  String get checkInOtherMoodHint;

  /// No description provided for @checkInEnergyLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Energia percebida: {value}/10'**
  String checkInEnergyLabel(Object value);

  /// No description provided for @checkInReflectionLabel.
  ///
  /// In pt_BR, this message translates to:
  /// **'Escreva o que sentir vontade. Este espaço é seu.'**
  String get checkInReflectionLabel;

  /// No description provided for @checkInReflectionHint.
  ///
  /// In pt_BR, this message translates to:
  /// **'Uma frase simples ajuda a leitura ficar mais precisa.'**
  String get checkInReflectionHint;

  /// No description provided for @checkInSubmit.
  ///
  /// In pt_BR, this message translates to:
  /// **'Fazer check-in'**
  String get checkInSubmit;

  /// No description provided for @checkInNotNow.
  ///
  /// In pt_BR, this message translates to:
  /// **'Agora não'**
  String get checkInNotNow;

  /// No description provided for @checkInSavedSnack.
  ///
  /// In pt_BR, this message translates to:
  /// **'Check-in registrado. Continue no seu ritmo.'**
  String get checkInSavedSnack;

  /// No description provided for @checkInSaveError.
  ///
  /// In pt_BR, this message translates to:
  /// **'Não foi possível salvar o check-in.'**
  String get checkInSaveError;

  /// No description provided for @checkInDeepReadingTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Deseja desbloquear mais uma leitura emocional?'**
  String get checkInDeepReadingTitle;

  /// No description provided for @checkInDeepReadingMessage.
  ///
  /// In pt_BR, this message translates to:
  /// **'Seu check-in foi salvo. A leitura básica continua disponível, e você pode liberar uma leitura aprofundada assistindo a um anúncio ou assinando Premium.'**
  String get checkInDeepReadingMessage;

  /// No description provided for @checkInDeepReadingReward.
  ///
  /// In pt_BR, this message translates to:
  /// **'Recompensa: +1 leitura emocional aprofundada hoje.'**
  String get checkInDeepReadingReward;

  /// No description provided for @checkInDeepReadingUnlocked.
  ///
  /// In pt_BR, this message translates to:
  /// **'Leitura aprofundada liberada para hoje.'**
  String get checkInDeepReadingUnlocked;

  /// No description provided for @checkInRewardAdNotConfirmed.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tivemos um problema para confirmar o anúncio. Tente novamente em instantes.'**
  String get checkInRewardAdNotConfirmed;

  /// No description provided for @checkInPremiumAction.
  ///
  /// In pt_BR, this message translates to:
  /// **'Assinar Premium'**
  String get checkInPremiumAction;

  /// No description provided for @checkInChooseStateTitle.
  ///
  /// In pt_BR, this message translates to:
  /// **'Escolha um estado'**
  String get checkInChooseStateTitle;

  /// No description provided for @checkInSearchState.
  ///
  /// In pt_BR, this message translates to:
  /// **'Buscar estado'**
  String get checkInSearchState;

  /// No description provided for @checkInRecentStates.
  ///
  /// In pt_BR, this message translates to:
  /// **'Recentes'**
  String get checkInRecentStates;

  /// No description provided for @checkInAiSuggestedStates.
  ///
  /// In pt_BR, this message translates to:
  /// **'Sugeridos pela IA'**
  String get checkInAiSuggestedStates;

  /// No description provided for @checkInMoodGroupEmotional.
  ///
  /// In pt_BR, this message translates to:
  /// **'Emocionais'**
  String get checkInMoodGroupEmotional;

  /// No description provided for @checkInMoodGroupMental.
  ///
  /// In pt_BR, this message translates to:
  /// **'Mentais'**
  String get checkInMoodGroupMental;

  /// No description provided for @checkInMoodGroupPhysical.
  ///
  /// In pt_BR, this message translates to:
  /// **'Físicos'**
  String get checkInMoodGroupPhysical;

  /// No description provided for @checkInMoodGroupBehavioral.
  ///
  /// In pt_BR, this message translates to:
  /// **'Comportamentais'**
  String get checkInMoodGroupBehavioral;

  /// No description provided for @checkInMoodGroupOther.
  ///
  /// In pt_BR, this message translates to:
  /// **'Outros'**
  String get checkInMoodGroupOther;

  /// No description provided for @checkInMoodCalm.
  ///
  /// In pt_BR, this message translates to:
  /// **'Calma'**
  String get checkInMoodCalm;

  /// No description provided for @checkInMoodAnxiety.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ansiedade'**
  String get checkInMoodAnxiety;

  /// No description provided for @checkInMoodTiredness.
  ///
  /// In pt_BR, this message translates to:
  /// **'Cansaço'**
  String get checkInMoodTiredness;

  /// No description provided for @checkInMoodDistraction.
  ///
  /// In pt_BR, this message translates to:
  /// **'Distração'**
  String get checkInMoodDistraction;

  /// No description provided for @checkInMoodSadness.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tristeza'**
  String get checkInMoodSadness;

  /// No description provided for @checkInMoodEnthusiasm.
  ///
  /// In pt_BR, this message translates to:
  /// **'Ânimo'**
  String get checkInMoodEnthusiasm;

  /// No description provided for @checkInMoodIrritation.
  ///
  /// In pt_BR, this message translates to:
  /// **'Irritação'**
  String get checkInMoodIrritation;

  /// No description provided for @checkInMoodHope.
  ///
  /// In pt_BR, this message translates to:
  /// **'Esperança'**
  String get checkInMoodHope;

  /// No description provided for @checkInMoodOverload.
  ///
  /// In pt_BR, this message translates to:
  /// **'Sobrecarga'**
  String get checkInMoodOverload;

  /// No description provided for @checkInMoodFocus.
  ///
  /// In pt_BR, this message translates to:
  /// **'Foco'**
  String get checkInMoodFocus;

  /// No description provided for @checkInMoodConfusion.
  ///
  /// In pt_BR, this message translates to:
  /// **'Confusão'**
  String get checkInMoodConfusion;

  /// No description provided for @checkInMoodCreativity.
  ///
  /// In pt_BR, this message translates to:
  /// **'Criatividade'**
  String get checkInMoodCreativity;

  /// No description provided for @checkInMoodAcceleration.
  ///
  /// In pt_BR, this message translates to:
  /// **'Aceleração'**
  String get checkInMoodAcceleration;

  /// No description provided for @checkInMoodBlock.
  ///
  /// In pt_BR, this message translates to:
  /// **'Bloqueio'**
  String get checkInMoodBlock;

  /// No description provided for @checkInMoodEnergy.
  ///
  /// In pt_BR, this message translates to:
  /// **'Energia'**
  String get checkInMoodEnergy;

  /// No description provided for @checkInMoodTension.
  ///
  /// In pt_BR, this message translates to:
  /// **'Tensão'**
  String get checkInMoodTension;

  /// No description provided for @checkInMoodLightness.
  ///
  /// In pt_BR, this message translates to:
  /// **'Leveza'**
  String get checkInMoodLightness;

  /// No description provided for @checkInMoodSleepiness.
  ///
  /// In pt_BR, this message translates to:
  /// **'Sonolência'**
  String get checkInMoodSleepiness;

  /// No description provided for @checkInMoodAgitation.
  ///
  /// In pt_BR, this message translates to:
  /// **'Agitação'**
  String get checkInMoodAgitation;

  /// No description provided for @checkInMoodAvoidance.
  ///
  /// In pt_BR, this message translates to:
  /// **'Evitação'**
  String get checkInMoodAvoidance;

  /// No description provided for @checkInMoodProductivity.
  ///
  /// In pt_BR, this message translates to:
  /// **'Produtividade'**
  String get checkInMoodProductivity;

  /// No description provided for @checkInMoodIsolation.
  ///
  /// In pt_BR, this message translates to:
  /// **'Isolamento'**
  String get checkInMoodIsolation;

  /// No description provided for @checkInMoodConnection.
  ///
  /// In pt_BR, this message translates to:
  /// **'Conexão'**
  String get checkInMoodConnection;

  /// No description provided for @checkInMoodProcrastination.
  ///
  /// In pt_BR, this message translates to:
  /// **'Procrastinação'**
  String get checkInMoodProcrastination;

  /// No description provided for @checkInMoodConsistency.
  ///
  /// In pt_BR, this message translates to:
  /// **'Constância'**
  String get checkInMoodConsistency;

  /// No description provided for @checkInMoodOther.
  ///
  /// In pt_BR, this message translates to:
  /// **'Outro estado'**
  String get checkInMoodOther;

  /// No description provided for @dailyRitualCarryMorning.
  ///
  /// In pt_BR, this message translates to:
  /// **'Leve isso com você hoje'**
  String get dailyRitualCarryMorning;

  /// No description provided for @dailyRitualCarryEvening.
  ///
  /// In pt_BR, this message translates to:
  /// **'Guarde isso do seu dia'**
  String get dailyRitualCarryEvening;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'US':
            return AppLocalizationsEnUs();
        }
        break;
      }
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

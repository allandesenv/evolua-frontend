// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Evolua';

  @override
  String get authFormSemanticLabel => 'Formulário de autenticação';

  @override
  String get authLoginTab => 'Entrar';

  @override
  String get authRegisterTab => 'Criar conta';

  @override
  String get authGoogleContinue => 'Continuar com Google';

  @override
  String get authLoginFallbackError =>
      'Não foi possível autenticar. Revise os dados e tente novamente.';

  @override
  String get authGoogleStartError =>
      'Não foi possível iniciar o login com Google. Tente novamente.';

  @override
  String get authDisplayNameLabel => 'Nome';

  @override
  String get authDisplayNameHint => 'Como você quer ser chamado';

  @override
  String get authBirthDateLabel => 'Data de nascimento';

  @override
  String get authBirthDateEmpty => 'Selecione sua data';

  @override
  String get authBirthDateHint => 'dd/mm/aaaa';

  @override
  String get authBirthDateOpenPicker => 'Abrir calendário';

  @override
  String get authGenderLabel => 'Gênero';

  @override
  String get authGenderMale => 'Masculino';

  @override
  String get authGenderFemale => 'Feminino';

  @override
  String get authGenderPreferNotToSay => 'Prefiro não informar';

  @override
  String get authGenderCustom => 'Personalizado';

  @override
  String get authCustomGenderLabel => 'Como você se identifica';

  @override
  String get authCustomGenderHint => 'Escreva do seu jeito';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authEmailHint => 'voce@evolua.app';

  @override
  String get authPasswordLabel => 'Senha';

  @override
  String get authPasswordHint => 'De 6 a 72 caracteres';

  @override
  String get authConfirmPasswordLabel => 'Confirmar senha';

  @override
  String get authConfirmPasswordHint => 'Digite a senha novamente';

  @override
  String get authPasswordRules =>
      'Use de 6 a 72 caracteres. Você pode usar letras, números e símbolos.';

  @override
  String get authHidePassword => 'Ocultar senha';

  @override
  String get authShowPassword => 'Mostrar senha';

  @override
  String get authForgotPassword => 'Esqueci minha senha';

  @override
  String get authForgotPasswordTitle => 'Recuperar senha';

  @override
  String get authForgotPasswordBody =>
      'Informe seu e-mail de acesso. Se ele estiver cadastrado, enviaremos um link para criar uma nova senha.';

  @override
  String get authForgotPasswordSuccess =>
      'Se este e-mail estiver cadastrado, enviaremos as instruções de recuperação.';

  @override
  String get authForgotPasswordError =>
      'Não foi possível solicitar a recuperação agora.';

  @override
  String get authForgotPasswordTimeout =>
      'Não conseguimos confirmar o envio agora. Tente novamente em instantes.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonLoading => 'Carregando...';

  @override
  String get commonSaving => 'Salvando...';

  @override
  String get commonSending => 'Enviando...';

  @override
  String get commonSend => 'Enviar';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonRefresh => 'Atualizar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonNext => 'Próximo';

  @override
  String get commonPrevious => 'Anterior';

  @override
  String get errorNetwork =>
      'Não foi possível conectar agora. Verifique sua conexão e tente novamente.';

  @override
  String get errorNoInternet =>
      'Não conseguimos conectar agora. Verifique sua internet e tente novamente.';

  @override
  String get errorTimeout =>
      'A resposta demorou mais que o esperado. Tente novamente em instantes.';

  @override
  String get errorSessionExpired =>
      'Sua sessão expirou. Entre novamente para continuar.';

  @override
  String get errorServerUnavailable =>
      'O Evolua está temporariamente indisponível. Tente novamente em alguns instantes.';

  @override
  String get errorCheckInQuota =>
      'Você já fez o check-in gratuito de hoje. Assista a um anúncio, assine Premium ou volte amanhã.';

  @override
  String get errorSmartReadingUnavailable =>
      'Seu check-in está salvo, mas não conseguimos preparar a leitura agora.';

  @override
  String get errorRewardedAdUnavailable =>
      'Não foi possível carregar o anúncio agora. Tente novamente em instantes.';

  @override
  String get errorUnexpected =>
      'Não foi possível concluir agora. Tente novamente em instantes.';

  @override
  String get errorTryAgainLater =>
      'Não foi possível concluir agora. Tente novamente mais tarde.';

  @override
  String get emptyDefaultTitle => 'Nada por aqui ainda';

  @override
  String get emptyDefaultBody =>
      'Quando houver novidades, elas aparecerão neste espaço.';

  @override
  String get authSendLink => 'Enviar link';

  @override
  String get authResendLink => 'Reenviar link';

  @override
  String get authSendingLink => 'Enviando...';

  @override
  String get resetPasswordSemanticLabel => 'Redefinir senha';

  @override
  String get resetPasswordInvalidLink => 'Link de recuperação inválido.';

  @override
  String get resetPasswordCompletedSnack =>
      'Senha redefinida. Você já pode entrar.';

  @override
  String get resetPasswordError => 'Não foi possível redefinir sua senha.';

  @override
  String get resetPasswordCreateTitle => 'Criar nova senha';

  @override
  String get resetPasswordCreateBody =>
      'Escolha uma senha com ao menos 6 caracteres para voltar ao Evolua.';

  @override
  String get resetPasswordNewLabel => 'Nova senha';

  @override
  String get resetPasswordConfirmLabel => 'Confirmar nova senha';

  @override
  String get resetPasswordMismatch => 'As senhas não conferem.';

  @override
  String get resetPasswordSubmit => 'Redefinir senha';

  @override
  String get resetPasswordBackToLogin => 'Voltar para entrar';

  @override
  String get resetPasswordSuccessTitle => 'Senha redefinida';

  @override
  String get resetPasswordSuccessBody =>
      'Agora você pode entrar usando sua nova senha.';

  @override
  String get authHeroTitle => 'Continue sua jornada';

  @override
  String get authHeroSubtitle =>
      'Acesse seu espaço de autoconhecimento em poucos segundos.';

  @override
  String get authHeroQuickCheckIn => 'Check-in rápido';

  @override
  String get authHeroShortTrails => 'Trilhas curtas';

  @override
  String get authHeroReflections => 'Reflexões do momento';

  @override
  String get navHome => 'Início';

  @override
  String get navTrails => 'Trilhas';

  @override
  String get navSpaces => 'Espaços';

  @override
  String get navMirror => 'Espelho';

  @override
  String get navAdminPanel => 'Painel Admin';

  @override
  String get navProfile => 'Perfil';

  @override
  String get avatarFutureMessages => 'Mensagens para o futuro';

  @override
  String get avatarPlans => 'Planos e assinaturas';

  @override
  String get avatarEvolutionMirror => 'Espelho da Evolução';

  @override
  String get avatarLogout => 'Sair';

  @override
  String get avatarSignatureCreatedBy => 'Criado com cuidado pela Zenith IT';

  @override
  String get avatarSignatureVersion => 'Evolua v1.0.0';

  @override
  String get languageSectionTitle => 'Idioma';

  @override
  String get languageSectionSubtitle =>
      'Escolha como o Evolua deve aparecer para você.';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get languageEnglish => 'English (US)';

  @override
  String get languageSystem => 'Usar idioma do sistema';

  @override
  String get settingsPrivacyTitle => 'Configurações e privacidade';

  @override
  String get settingsPreferencesSaved => 'Preferências salvas com segurança.';

  @override
  String get settingsVisualPreferencesSaved =>
      'Preferências visuais salvas com conforto.';

  @override
  String homeDailyMorningTitle(Object name) {
    return 'Bom dia, $name';
  }

  @override
  String get homeDailyMorningTitleNoName => 'Bom dia';

  @override
  String get homeDailyMorningBody =>
      'Comece o dia com presença. Escolha uma intenção simples e uma microação possível.';

  @override
  String get homeDailyMorningPrimary => 'Iniciar Ritual do Dia';

  @override
  String get homeDailyDayTitle => 'Como está seu dia até aqui?';

  @override
  String get homeDailyDayBody =>
      'Faça uma pausa curta para perceber seu estado e escolher o próximo passo.';

  @override
  String get homeDailyDayPrimary => 'Fazer check-in';

  @override
  String get homeDailyDaySecondary => 'Ver próximo passo';

  @override
  String get homeDailyEveningTitle => 'Vamos fechar o dia?';

  @override
  String get homeDailyEveningBody =>
      'Revise o que pesou, reconheça o que foi bom e solte o que não precisa carregar.';

  @override
  String get homeDailyEveningPrimary => 'Fazer Fechamento do Dia';

  @override
  String get homeDailyEveningSecondary => 'Escrever reflexão';

  @override
  String get homeDailyRitualDone => 'Ritual do Dia concluído';

  @override
  String get homeDailyClosingDone => 'Fechamento do Dia concluído';

  @override
  String get homeDailyViewRitual => 'Ver meu ritual';

  @override
  String get firstExperienceTitle => 'Bem-vindo ao Evolua';

  @override
  String get firstExperienceMainMessage =>
      'Vamos começar com um check-in simples. Leva menos de um minuto.';

  @override
  String get firstExperienceDescription =>
      'A partir dele, o Evolua prepara sua leitura inteligente e sugere um próximo passo leve para hoje.';

  @override
  String get firstExperienceStart => 'Começar check-in';

  @override
  String get firstExperienceNotNow => 'Agora não';

  @override
  String get homeFutureLetter => 'Carta para o futuro';

  @override
  String get homeRecentReflection => 'Reflexão recente';

  @override
  String get homeQuickInsight => 'Insight rápido';

  @override
  String get homeEvolutionMilestone => 'Marco de evolução';

  @override
  String get homeIntelligentReadingEyebrow => 'O que isso significa?';

  @override
  String get homeIntelligentReadingTitle => 'Olhar do Evolua';

  @override
  String get homeIntelligentReadingEmpty =>
      'Depois do próximo check-in, a IA resume o momento e transforma a leitura em uma ação simples.';

  @override
  String get homeSmartReadingGeneratingTitle => 'Gerando leitura...';

  @override
  String get homeSmartReadingGeneratingBody =>
      'Você já pode continuar. Estamos preparando a leitura para este momento.';

  @override
  String get homeSmartReadingUnavailableTitle => 'Leitura indisponível agora';

  @override
  String get homeSmartReadingUnavailableBody =>
      'Não conseguimos gerar a leitura agora, mas seu check-in foi salvo.';

  @override
  String get homeFullAnalysis => 'Ver análise completa';

  @override
  String get homeMirrorRewardTitle =>
      'Seu check-in já conta para o seu Espelho';

  @override
  String get homeMirrorRewardDescription =>
      'Quanto mais você registra, mais seu Espelho revela padrões.';

  @override
  String get homeMirrorRewardAnalysis => 'Ver análise';

  @override
  String get homeMirrorRewardTrail => 'Continuar trilha';

  @override
  String get homeMirrorRewardMirror => 'Ver meu Espelho';

  @override
  String homeEnergyBullet(Object value) {
    return 'Energia: $value/10';
  }

  @override
  String homeStateBullet(Object value) {
    return 'Estado: $value';
  }

  @override
  String homeBestResponseBullet(Object value) {
    return 'Melhor resposta agora: $value';
  }

  @override
  String get trailCatalog => 'Catálogo';

  @override
  String get trailMyJourney => 'Trilha atual';

  @override
  String get trailStart => 'Iniciar trilha';

  @override
  String get trailCompleteJourney => 'Trilha completa';

  @override
  String get trailViewCatalog => 'Ver catálogo';

  @override
  String get trailNoActiveJourney => 'Sem trilha ativa.';

  @override
  String get trailVideo => 'Vídeo';

  @override
  String get trailListen => 'Ouvir';

  @override
  String get trailPause => 'Pausar';

  @override
  String get trailStop => 'Parar';

  @override
  String get trailFullscreen => 'Tela cheia';

  @override
  String get trailSpeed => 'Velocidade';

  @override
  String get trailVideoUnavailable => 'Não foi possível preparar este vídeo.';

  @override
  String get adminTrailsTitle => 'Admin de trilhas';

  @override
  String get adminNotificationsTitle => 'Admin de notificações';

  @override
  String get spacesFeatured => 'Em destaque';

  @override
  String get spacesReflections => 'Reflexões';

  @override
  String get spacesMine => 'Meus';

  @override
  String get futureMessagesTitle => 'Mensagens para o futuro';

  @override
  String get mirrorTitle => 'Espelho da Evolução';

  @override
  String get profileChangePhoto => 'Trocar foto';

  @override
  String get profileUpdate => 'Atualizar';

  @override
  String get notificationsTitle => 'Notificações';

  @override
  String get plansTitle => 'Planos e assinaturas';

  @override
  String get checkInTitle => 'Check-in';

  @override
  String get checkInSemanticLabel => 'Check-in do dia';

  @override
  String get checkInEyebrow => '';

  @override
  String get checkInPromptTitle => 'Como você está se sentindo agora?';

  @override
  String get checkInPromptSubtitle =>
      'Escolha a opção que mais combina com este momento.';

  @override
  String get checkInMoreStatesTooltip => 'Ver mais estados';

  @override
  String get checkInMoreStates => 'Mais estados';

  @override
  String checkInSelectedState(Object state) {
    return 'Estado selecionado: $state';
  }

  @override
  String get checkInOtherMoodLabel => 'Descreva com suas palavras';

  @override
  String get checkInOtherMoodHint =>
      'Opcional: escreva como você está se sentindo';

  @override
  String checkInEnergyLabel(Object value) {
    return 'Energia percebida: $value/10';
  }

  @override
  String get checkInReflectionLabel =>
      'Escreva o que sentir vontade. Este espaço é seu.';

  @override
  String get checkInReflectionHint =>
      'Uma frase simples ajuda a leitura ficar mais precisa.';

  @override
  String get checkInSubmit => 'Fazer check-in';

  @override
  String get checkInSavingLabel => 'Salvando check-in...';

  @override
  String get checkInNotNow => 'Agora não';

  @override
  String get checkInSavedSnack => 'Check-in registrado. Continue no seu ritmo.';

  @override
  String get checkInSavedReadingPending =>
      'Check-in salvo. Você já pode continuar, a leitura aparecerá em instantes.';

  @override
  String get checkInSavingInProgress =>
      'Estamos salvando seu check-in. Aguarde alguns instantes.';

  @override
  String get checkInSaveError => 'Não foi possível salvar o check-in.';

  @override
  String get checkInDeepReadingTitle =>
      'Deseja desbloquear mais uma leitura emocional?';

  @override
  String get checkInDeepReadingMessage =>
      'Seu check-in foi salvo. A leitura básica continua disponível, e você pode liberar uma leitura aprofundada assistindo a um anúncio ou assinando Premium.';

  @override
  String get checkInDeepReadingReward =>
      'Recompensa: +1 leitura emocional aprofundada hoje.';

  @override
  String get checkInDeepReadingUnlocked =>
      'Leitura aprofundada liberada para hoje.';

  @override
  String get checkInRewardAdNotConfirmed =>
      'Tivemos um problema para confirmar o anúncio. Tente novamente em instantes.';

  @override
  String get checkInPremiumAction => 'Assinar Premium';

  @override
  String get checkInChooseStateTitle => 'Escolha um estado';

  @override
  String get checkInSearchState => 'Buscar estado';

  @override
  String get checkInRecentStates => 'Recentes';

  @override
  String get checkInAiSuggestedStates => 'Sugeridos pela IA';

  @override
  String get checkInMoodGroupEmotional => 'Emocionais';

  @override
  String get checkInMoodGroupMental => 'Mentais';

  @override
  String get checkInMoodGroupPhysical => 'Físicos';

  @override
  String get checkInMoodGroupBehavioral => 'Comportamentais';

  @override
  String get checkInMoodGroupOther => 'Outros';

  @override
  String get checkInMoodCalm => 'Calma';

  @override
  String get checkInMoodAnxiety => 'Ansiedade';

  @override
  String get checkInMoodTiredness => 'Cansaço';

  @override
  String get checkInMoodDistraction => 'Distração';

  @override
  String get checkInMoodSadness => 'Tristeza';

  @override
  String get checkInMoodEnthusiasm => 'Ânimo';

  @override
  String get checkInMoodIrritation => 'Irritação';

  @override
  String get checkInMoodHope => 'Esperança';

  @override
  String get checkInMoodOverload => 'Sobrecarga';

  @override
  String get checkInMoodFocus => 'Foco';

  @override
  String get checkInMoodConfusion => 'Confusão';

  @override
  String get checkInMoodCreativity => 'Criatividade';

  @override
  String get checkInMoodAcceleration => 'Aceleração';

  @override
  String get checkInMoodBlock => 'Bloqueio';

  @override
  String get checkInMoodEnergy => 'Energia';

  @override
  String get checkInMoodTension => 'Tensão';

  @override
  String get checkInMoodLightness => 'Leveza';

  @override
  String get checkInMoodSleepiness => 'Sonolência';

  @override
  String get checkInMoodAgitation => 'Agitação';

  @override
  String get checkInMoodAvoidance => 'Evitação';

  @override
  String get checkInMoodProductivity => 'Produtividade';

  @override
  String get checkInMoodIsolation => 'Isolamento';

  @override
  String get checkInMoodConnection => 'Conexão';

  @override
  String get checkInMoodProcrastination => 'Procrastinação';

  @override
  String get checkInMoodConsistency => 'Constância';

  @override
  String get checkInMoodOther => 'Outro estado';

  @override
  String get dailyRitualCarryMorning => 'Leve isso com você hoje';

  @override
  String get dailyRitualCarryEvening => 'Guarde isso do seu dia';

  @override
  String get dailyRitualAnswerAllSteps =>
      'Responda as quatro etapas no seu ritmo.';

  @override
  String get dailyRitualSavedMorning =>
      'Ritual salvo. Sua jornada diária já tem um norte.';

  @override
  String get dailyRitualSavedEvening =>
      'Fechamento salvo. Agora solte o que não precisa carregar.';

  @override
  String get dailyRitualOpenError => 'Não foi possível abrir seu ritual agora.';

  @override
  String get dailyRitualSaveError =>
      'Não foi possível salvar seu ritual agora.';

  @override
  String get dailyRitualMorningTitle => 'Ritual do Dia';

  @override
  String get dailyRitualMorningDescription =>
      'Uma pausa curta para perceber como você está, escolher uma intenção e definir um pequeno passo possível para hoje.';

  @override
  String get dailyRitualMorningResultTitle => 'Seu ritual de hoje está pronto';

  @override
  String get dailyRitualEveningTitle => 'Fechamento do Dia';

  @override
  String get dailyRitualEveningDescription =>
      'Uma pausa curta para revisar o que pesou, reconhecer o que foi bom e soltar o que não precisa carregar.';

  @override
  String get dailyRitualEveningResultTitle =>
      'Seu fechamento de hoje está pronto';

  @override
  String get dailyRitualDurationChip => 'Dura cerca de 2 minutos';

  @override
  String get dailyRitualNoRightWrongChip => 'Sem certo ou errado';

  @override
  String get dailyRitualAtYourPaceChip => 'No seu ritmo';

  @override
  String get dailyRitualStartNow => 'Começar agora';

  @override
  String get dailyRitualAnswerLabel => 'Sua resposta';

  @override
  String get dailyRitualContinue => 'Continuar';

  @override
  String get dailyRitualFinish => 'Concluir';

  @override
  String get dailyRitualEmotionalState => 'Estado emocional';

  @override
  String get dailyRitualDayNeed => 'Necessidade do dia';

  @override
  String get dailyRitualChosenIntention => 'Intenção escolhida';

  @override
  String get dailyRitualChosenMicroAction => 'Microação escolhida';

  @override
  String get dailyRitualBackHome => 'Voltar para Início';

  @override
  String get dailyRitualMorningQuestionState => 'Como você está agora?';

  @override
  String get dailyRitualMorningQuestionNeed => 'O que você mais precisa hoje?';

  @override
  String get dailyRitualMorningQuestionIntention =>
      'Qual intenção quer carregar hoje?';

  @override
  String get dailyRitualMorningQuestionAction =>
      'Qual pequeno passo consegue dar hoje?';

  @override
  String get dailyRitualEveningQuestionState => 'Como você está agora?';

  @override
  String get dailyRitualEveningQuestionNeed =>
      'O que você mais precisa soltar hoje?';

  @override
  String get dailyRitualEveningQuestionIntention =>
      'Qual intenção quer levar para o descanso?';

  @override
  String get dailyRitualEveningQuestionAction =>
      'Qual pequeno cuidado consegue fazer agora?';

  @override
  String get careLoadingSecureAccess => 'Carregando acesso seguro...';

  @override
  String get careLoadErrorTitle => 'Não foi possível carregar o Evolua Care';

  @override
  String get careLoadErrorMessage =>
      'Verifique sua conexão e tente novamente em instantes.';

  @override
  String get careRecommendationsLoading =>
      'Carregando orientações do terapeuta...';

  @override
  String get careRecommendationsError =>
      'Não foi possível carregar as orientações agora.';

  @override
  String get careRecommendationsTitle => 'Orientações do terapeuta';

  @override
  String get careRecommendationsSubtitle =>
      'Recomendações e anexos recebidos por acesso seguro.';

  @override
  String get careRecommendationsEmpty =>
      'Nenhuma orientação recebida por enquanto.';

  @override
  String get careTherapistFallback => 'Terapeuta';

  @override
  String get careAcknowledgeReading => 'Confirmar leitura';

  @override
  String get carePreparingAccess => 'Preparando acesso seguro...';

  @override
  String get careShareTitle => 'Compartilhe com seu terapeuta';

  @override
  String get careShareMessage =>
      'Gere um acesso temporário para que seu terapeuta veja um relatório protegido da sua jornada emocional.';

  @override
  String get careGenerateSecureAccess => 'Gerar acesso seguro';

  @override
  String get careExpiredTitle => 'Sessão expirada';

  @override
  String get careExpiredMessage =>
      'O acesso temporário venceu. Gere um novo código quando estiver com seu terapeuta.';

  @override
  String get careGenerateNewAccess => 'Gerar novo acesso';

  @override
  String get careRevokedTitle => 'Acesso revogado';

  @override
  String get careRevokedMessage =>
      'Seu terapeuta não pode mais acessar essa sessão compartilhada.';

  @override
  String get careQrMissing =>
      'Por segurança, gere um novo acesso para exibir o QR Code completo.';

  @override
  String get careTemporaryCode => 'Código temporário';

  @override
  String careExpiresAt(Object value) {
    return 'Expira em $value';
  }

  @override
  String get careCodeCopied => 'Código copiado com segurança.';

  @override
  String get careCopyCode => 'Copiar código';

  @override
  String get careFullLinkCopied => 'Link completo copiado com segurança.';

  @override
  String get careCopyFullLink => 'Copiar link completo';

  @override
  String get careRevokeAccess => 'Revogar acesso';

  @override
  String get careConnectedTitle => 'Conectado ao terapeuta';

  @override
  String get careActiveTitle => 'Acesso temporário ativo';

  @override
  String get careConnectedMessage =>
      'Seu terapeuta validou o acesso. Você pode revogar quando quiser.';

  @override
  String get careActiveMessage =>
      'Mostre o QR Code ou o código ao seu terapeuta somente durante a consulta.';

  @override
  String get careHistoryLoading => 'Carregando histórico de conexões...';

  @override
  String get careHistoryError =>
      'Não foi possível carregar o histórico agora. Tente novamente mais tarde.';

  @override
  String get careHistoryTitle => 'Histórico de conexões';

  @override
  String get careHistorySubtitle =>
      'Acompanhe os acessos temporários criados para atendimento.';

  @override
  String get careHistoryEmpty => 'Nenhuma conexão anterior por enquanto.';

  @override
  String careHistoryTile(Object status, Object date) {
    return 'Sessão com terapeuta $status em $date';
  }

  @override
  String get careStatusConnected => 'conectada';

  @override
  String get careStatusRevoked => 'revogada';

  @override
  String get careStatusExpired => 'expirada';

  @override
  String get careStatusActive => 'ativa';

  @override
  String get careStatusRegistered => 'registrada';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get appTitle => 'Evolua';

  @override
  String get authFormSemanticLabel => 'Formulário de autenticação';

  @override
  String get authLoginTab => 'Entrar';

  @override
  String get authRegisterTab => 'Criar conta';

  @override
  String get authGoogleContinue => 'Continuar com Google';

  @override
  String get authLoginFallbackError =>
      'Não foi possível autenticar. Revise os dados e tente novamente.';

  @override
  String get authGoogleStartError =>
      'Não foi possível iniciar o login com Google. Tente novamente.';

  @override
  String get authDisplayNameLabel => 'Nome';

  @override
  String get authDisplayNameHint => 'Como você quer ser chamado';

  @override
  String get authBirthDateLabel => 'Data de nascimento';

  @override
  String get authBirthDateEmpty => 'Selecione sua data';

  @override
  String get authBirthDateHint => 'dd/mm/aaaa';

  @override
  String get authBirthDateOpenPicker => 'Abrir calendário';

  @override
  String get authGenderLabel => 'Gênero';

  @override
  String get authGenderMale => 'Masculino';

  @override
  String get authGenderFemale => 'Feminino';

  @override
  String get authGenderPreferNotToSay => 'Prefiro não informar';

  @override
  String get authGenderCustom => 'Personalizado';

  @override
  String get authCustomGenderLabel => 'Como você se identifica';

  @override
  String get authCustomGenderHint => 'Escreva do seu jeito';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authEmailHint => 'voce@evolua.app';

  @override
  String get authPasswordLabel => 'Senha';

  @override
  String get authPasswordHint => 'De 6 a 72 caracteres';

  @override
  String get authConfirmPasswordLabel => 'Confirmar senha';

  @override
  String get authConfirmPasswordHint => 'Digite a senha novamente';

  @override
  String get authPasswordRules =>
      'Use de 6 a 72 caracteres. Você pode usar letras, números e símbolos.';

  @override
  String get authHidePassword => 'Ocultar senha';

  @override
  String get authShowPassword => 'Mostrar senha';

  @override
  String get authForgotPassword => 'Esqueci minha senha';

  @override
  String get authForgotPasswordTitle => 'Recuperar senha';

  @override
  String get authForgotPasswordBody =>
      'Informe seu e-mail de acesso. Se ele estiver cadastrado, enviaremos um link para criar uma nova senha.';

  @override
  String get authForgotPasswordSuccess =>
      'Se este e-mail estiver cadastrado, enviaremos as instruções de recuperação.';

  @override
  String get authForgotPasswordError =>
      'Não foi possível solicitar a recuperação agora.';

  @override
  String get authForgotPasswordTimeout =>
      'Não conseguimos confirmar o envio agora. Tente novamente em instantes.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonLoading => 'Carregando...';

  @override
  String get commonSaving => 'Salvando...';

  @override
  String get commonSending => 'Enviando...';

  @override
  String get commonSend => 'Enviar';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonRefresh => 'Atualizar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonNext => 'Próximo';

  @override
  String get commonPrevious => 'Anterior';

  @override
  String get errorNetwork =>
      'Não foi possível conectar agora. Verifique sua conexão e tente novamente.';

  @override
  String get errorNoInternet =>
      'Não conseguimos conectar agora. Verifique sua internet e tente novamente.';

  @override
  String get errorTimeout =>
      'A resposta demorou mais que o esperado. Tente novamente em instantes.';

  @override
  String get errorSessionExpired =>
      'Sua sessão expirou. Entre novamente para continuar.';

  @override
  String get errorServerUnavailable =>
      'O Evolua está temporariamente indisponível. Tente novamente em alguns instantes.';

  @override
  String get errorCheckInQuota =>
      'Você já fez o check-in gratuito de hoje. Assista a um anúncio, assine Premium ou volte amanhã.';

  @override
  String get errorSmartReadingUnavailable =>
      'Seu check-in está salvo, mas não conseguimos preparar a leitura agora.';

  @override
  String get errorRewardedAdUnavailable =>
      'Não foi possível carregar o anúncio agora. Tente novamente em instantes.';

  @override
  String get errorUnexpected =>
      'Não foi possível concluir agora. Tente novamente em instantes.';

  @override
  String get errorTryAgainLater =>
      'Não foi possível concluir agora. Tente novamente mais tarde.';

  @override
  String get emptyDefaultTitle => 'Nada por aqui ainda';

  @override
  String get emptyDefaultBody =>
      'Quando houver novidades, elas aparecerão neste espaço.';

  @override
  String get authSendLink => 'Enviar link';

  @override
  String get authResendLink => 'Reenviar link';

  @override
  String get authSendingLink => 'Enviando...';

  @override
  String get resetPasswordSemanticLabel => 'Redefinir senha';

  @override
  String get resetPasswordInvalidLink => 'Link de recuperação inválido.';

  @override
  String get resetPasswordCompletedSnack =>
      'Senha redefinida. Você já pode entrar.';

  @override
  String get resetPasswordError => 'Não foi possível redefinir sua senha.';

  @override
  String get resetPasswordCreateTitle => 'Criar nova senha';

  @override
  String get resetPasswordCreateBody =>
      'Escolha uma senha com ao menos 6 caracteres para voltar ao Evolua.';

  @override
  String get resetPasswordNewLabel => 'Nova senha';

  @override
  String get resetPasswordConfirmLabel => 'Confirmar nova senha';

  @override
  String get resetPasswordMismatch => 'As senhas não conferem.';

  @override
  String get resetPasswordSubmit => 'Redefinir senha';

  @override
  String get resetPasswordBackToLogin => 'Voltar para entrar';

  @override
  String get resetPasswordSuccessTitle => 'Senha redefinida';

  @override
  String get resetPasswordSuccessBody =>
      'Agora você pode entrar usando sua nova senha.';

  @override
  String get authHeroTitle => 'Continue sua jornada';

  @override
  String get authHeroSubtitle =>
      'Acesse seu espaço de autoconhecimento em poucos segundos.';

  @override
  String get authHeroQuickCheckIn => 'Check-in rápido';

  @override
  String get authHeroShortTrails => 'Trilhas curtas';

  @override
  String get authHeroReflections => 'Reflexões do momento';

  @override
  String get navHome => 'Início';

  @override
  String get navTrails => 'Trilhas';

  @override
  String get navSpaces => 'Espaços';

  @override
  String get navMirror => 'Espelho';

  @override
  String get navAdminPanel => 'Painel Admin';

  @override
  String get navProfile => 'Perfil';

  @override
  String get avatarFutureMessages => 'Mensagens para o futuro';

  @override
  String get avatarPlans => 'Planos e assinaturas';

  @override
  String get avatarEvolutionMirror => 'Espelho da Evolução';

  @override
  String get avatarLogout => 'Sair';

  @override
  String get avatarSignatureCreatedBy => 'Criado com cuidado pela Zenith IT';

  @override
  String get avatarSignatureVersion => 'Evolua v1.0.0';

  @override
  String get languageSectionTitle => 'Idioma';

  @override
  String get languageSectionSubtitle =>
      'Escolha como o Evolua deve aparecer para você.';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get languageEnglish => 'English (US)';

  @override
  String get languageSystem => 'Usar idioma do sistema';

  @override
  String get settingsPrivacyTitle => 'Configurações e privacidade';

  @override
  String get settingsPreferencesSaved => 'Preferências salvas com segurança.';

  @override
  String get settingsVisualPreferencesSaved =>
      'Preferências visuais salvas com conforto.';

  @override
  String homeDailyMorningTitle(Object name) {
    return 'Bom dia, $name';
  }

  @override
  String get homeDailyMorningTitleNoName => 'Bom dia';

  @override
  String get homeDailyMorningBody =>
      'Comece o dia com presença. Escolha uma intenção simples e uma microação possível.';

  @override
  String get homeDailyMorningPrimary => 'Iniciar Ritual do Dia';

  @override
  String get homeDailyDayTitle => 'Como está seu dia até aqui?';

  @override
  String get homeDailyDayBody =>
      'Faça uma pausa curta para perceber seu estado e escolher o próximo passo.';

  @override
  String get homeDailyDayPrimary => 'Fazer check-in';

  @override
  String get homeDailyDaySecondary => 'Ver próximo passo';

  @override
  String get homeDailyEveningTitle => 'Vamos fechar o dia?';

  @override
  String get homeDailyEveningBody =>
      'Revise o que pesou, reconheça o que foi bom e solte o que não precisa carregar.';

  @override
  String get homeDailyEveningPrimary => 'Fazer Fechamento do Dia';

  @override
  String get homeDailyEveningSecondary => 'Escrever reflexão';

  @override
  String get homeDailyRitualDone => 'Ritual do Dia concluído';

  @override
  String get homeDailyClosingDone => 'Fechamento do Dia concluído';

  @override
  String get homeDailyViewRitual => 'Ver meu ritual';

  @override
  String get firstExperienceTitle => 'Bem-vindo ao Evolua';

  @override
  String get firstExperienceMainMessage =>
      'Vamos começar com um check-in simples. Leva menos de um minuto.';

  @override
  String get firstExperienceDescription =>
      'A partir dele, o Evolua prepara sua leitura inteligente e sugere um próximo passo leve para hoje.';

  @override
  String get firstExperienceStart => 'Começar check-in';

  @override
  String get firstExperienceNotNow => 'Agora não';

  @override
  String get homeFutureLetter => 'Carta para o futuro';

  @override
  String get homeRecentReflection => 'Reflexão recente';

  @override
  String get homeQuickInsight => 'Insight rápido';

  @override
  String get homeEvolutionMilestone => 'Marco de evolução';

  @override
  String get homeIntelligentReadingEyebrow => 'O que isso significa?';

  @override
  String get homeIntelligentReadingTitle => 'Olhar do Evolua';

  @override
  String get homeIntelligentReadingEmpty =>
      'Depois do próximo check-in, a IA resume o momento e transforma a leitura em uma ação simples.';

  @override
  String get homeSmartReadingGeneratingTitle => 'Gerando leitura...';

  @override
  String get homeSmartReadingGeneratingBody =>
      'Você já pode continuar. Estamos preparando a leitura para este momento.';

  @override
  String get homeSmartReadingUnavailableTitle => 'Leitura indisponível agora';

  @override
  String get homeSmartReadingUnavailableBody =>
      'Não conseguimos gerar a leitura agora, mas seu check-in foi salvo.';

  @override
  String get homeFullAnalysis => 'Ver análise completa';

  @override
  String get homeMirrorRewardTitle =>
      'Seu check-in já conta para o seu Espelho';

  @override
  String get homeMirrorRewardDescription =>
      'Quanto mais você registra, mais seu Espelho revela padrões.';

  @override
  String get homeMirrorRewardAnalysis => 'Ver análise';

  @override
  String get homeMirrorRewardTrail => 'Continuar trilha';

  @override
  String get homeMirrorRewardMirror => 'Ver meu Espelho';

  @override
  String homeEnergyBullet(Object value) {
    return 'Energia: $value/10';
  }

  @override
  String homeStateBullet(Object value) {
    return 'Estado: $value';
  }

  @override
  String homeBestResponseBullet(Object value) {
    return 'Melhor resposta agora: $value';
  }

  @override
  String get trailCatalog => 'Catálogo';

  @override
  String get trailMyJourney => 'Trilha atual';

  @override
  String get trailStart => 'Iniciar trilha';

  @override
  String get trailCompleteJourney => 'Trilha completa';

  @override
  String get trailViewCatalog => 'Ver catálogo';

  @override
  String get trailNoActiveJourney => 'Sem trilha ativa.';

  @override
  String get trailVideo => 'Vídeo';

  @override
  String get trailListen => 'Ouvir';

  @override
  String get trailPause => 'Pausar';

  @override
  String get trailStop => 'Parar';

  @override
  String get trailFullscreen => 'Tela cheia';

  @override
  String get trailSpeed => 'Velocidade';

  @override
  String get trailVideoUnavailable => 'Não foi possível preparar este vídeo.';

  @override
  String get adminTrailsTitle => 'Admin de trilhas';

  @override
  String get adminNotificationsTitle => 'Admin de notificações';

  @override
  String get spacesFeatured => 'Em destaque';

  @override
  String get spacesReflections => 'Reflexões';

  @override
  String get spacesMine => 'Meus';

  @override
  String get futureMessagesTitle => 'Mensagens para o futuro';

  @override
  String get mirrorTitle => 'Espelho da Evolução';

  @override
  String get profileChangePhoto => 'Trocar foto';

  @override
  String get profileUpdate => 'Atualizar';

  @override
  String get notificationsTitle => 'Notificações';

  @override
  String get plansTitle => 'Planos e assinaturas';

  @override
  String get checkInTitle => 'Check-in';

  @override
  String get checkInSemanticLabel => 'Check-in do dia';

  @override
  String get checkInEyebrow => '';

  @override
  String get checkInPromptTitle => 'Como você está se sentindo agora?';

  @override
  String get checkInPromptSubtitle =>
      'Escolha a opção que mais combina com este momento.';

  @override
  String get checkInMoreStatesTooltip => 'Ver mais estados';

  @override
  String get checkInMoreStates => 'Mais estados';

  @override
  String checkInSelectedState(Object state) {
    return 'Estado selecionado: $state';
  }

  @override
  String get checkInOtherMoodLabel => 'Descreva com suas palavras';

  @override
  String get checkInOtherMoodHint =>
      'Opcional: escreva como você está se sentindo';

  @override
  String checkInEnergyLabel(Object value) {
    return 'Energia percebida: $value/10';
  }

  @override
  String get checkInReflectionLabel =>
      'Escreva o que sentir vontade. Este espaço é seu.';

  @override
  String get checkInReflectionHint =>
      'Uma frase simples ajuda a leitura ficar mais precisa.';

  @override
  String get checkInSubmit => 'Fazer check-in';

  @override
  String get checkInSavingLabel => 'Salvando check-in...';

  @override
  String get checkInNotNow => 'Agora não';

  @override
  String get checkInSavedSnack => 'Check-in registrado. Continue no seu ritmo.';

  @override
  String get checkInSavedReadingPending =>
      'Check-in salvo. Você já pode continuar, a leitura aparecerá em instantes.';

  @override
  String get checkInSavingInProgress =>
      'Estamos salvando seu check-in. Aguarde alguns instantes.';

  @override
  String get checkInSaveError => 'Não foi possível salvar o check-in.';

  @override
  String get checkInDeepReadingTitle =>
      'Deseja desbloquear mais uma leitura emocional?';

  @override
  String get checkInDeepReadingMessage =>
      'Seu check-in foi salvo. A leitura básica continua disponível, e você pode liberar uma leitura aprofundada assistindo a um anúncio ou assinando Premium.';

  @override
  String get checkInDeepReadingReward =>
      'Recompensa: +1 leitura emocional aprofundada hoje.';

  @override
  String get checkInDeepReadingUnlocked =>
      'Leitura aprofundada liberada para hoje.';

  @override
  String get checkInRewardAdNotConfirmed =>
      'Tivemos um problema para confirmar o anúncio. Tente novamente em instantes.';

  @override
  String get checkInPremiumAction => 'Assinar Premium';

  @override
  String get checkInChooseStateTitle => 'Escolha um estado';

  @override
  String get checkInSearchState => 'Buscar estado';

  @override
  String get checkInRecentStates => 'Recentes';

  @override
  String get checkInAiSuggestedStates => 'Sugeridos pela IA';

  @override
  String get checkInMoodGroupEmotional => 'Emocionais';

  @override
  String get checkInMoodGroupMental => 'Mentais';

  @override
  String get checkInMoodGroupPhysical => 'Físicos';

  @override
  String get checkInMoodGroupBehavioral => 'Comportamentais';

  @override
  String get checkInMoodGroupOther => 'Outros';

  @override
  String get checkInMoodCalm => 'Calma';

  @override
  String get checkInMoodAnxiety => 'Ansiedade';

  @override
  String get checkInMoodTiredness => 'Cansaço';

  @override
  String get checkInMoodDistraction => 'Distração';

  @override
  String get checkInMoodSadness => 'Tristeza';

  @override
  String get checkInMoodEnthusiasm => 'Ânimo';

  @override
  String get checkInMoodIrritation => 'Irritação';

  @override
  String get checkInMoodHope => 'Esperança';

  @override
  String get checkInMoodOverload => 'Sobrecarga';

  @override
  String get checkInMoodFocus => 'Foco';

  @override
  String get checkInMoodConfusion => 'Confusão';

  @override
  String get checkInMoodCreativity => 'Criatividade';

  @override
  String get checkInMoodAcceleration => 'Aceleração';

  @override
  String get checkInMoodBlock => 'Bloqueio';

  @override
  String get checkInMoodEnergy => 'Energia';

  @override
  String get checkInMoodTension => 'Tensão';

  @override
  String get checkInMoodLightness => 'Leveza';

  @override
  String get checkInMoodSleepiness => 'Sonolência';

  @override
  String get checkInMoodAgitation => 'Agitação';

  @override
  String get checkInMoodAvoidance => 'Evitação';

  @override
  String get checkInMoodProductivity => 'Produtividade';

  @override
  String get checkInMoodIsolation => 'Isolamento';

  @override
  String get checkInMoodConnection => 'Conexão';

  @override
  String get checkInMoodProcrastination => 'Procrastinação';

  @override
  String get checkInMoodConsistency => 'Constância';

  @override
  String get checkInMoodOther => 'Outro estado';

  @override
  String get dailyRitualCarryMorning => 'Leve isso com você hoje';

  @override
  String get dailyRitualCarryEvening => 'Guarde isso do seu dia';

  @override
  String get dailyRitualAnswerAllSteps =>
      'Responda as quatro etapas no seu ritmo.';

  @override
  String get dailyRitualSavedMorning =>
      'Ritual salvo. Sua jornada diária já tem um norte.';

  @override
  String get dailyRitualSavedEvening =>
      'Fechamento salvo. Agora solte o que não precisa carregar.';

  @override
  String get dailyRitualOpenError => 'Não foi possível abrir seu ritual agora.';

  @override
  String get dailyRitualSaveError =>
      'Não foi possível salvar seu ritual agora.';

  @override
  String get dailyRitualMorningTitle => 'Ritual do Dia';

  @override
  String get dailyRitualMorningDescription =>
      'Uma pausa curta para perceber como você está, escolher uma intenção e definir um pequeno passo possível para hoje.';

  @override
  String get dailyRitualMorningResultTitle => 'Seu ritual de hoje está pronto';

  @override
  String get dailyRitualEveningTitle => 'Fechamento do Dia';

  @override
  String get dailyRitualEveningDescription =>
      'Uma pausa curta para revisar o que pesou, reconhecer o que foi bom e soltar o que não precisa carregar.';

  @override
  String get dailyRitualEveningResultTitle =>
      'Seu fechamento de hoje está pronto';

  @override
  String get dailyRitualDurationChip => 'Dura cerca de 2 minutos';

  @override
  String get dailyRitualNoRightWrongChip => 'Sem certo ou errado';

  @override
  String get dailyRitualAtYourPaceChip => 'No seu ritmo';

  @override
  String get dailyRitualStartNow => 'Começar agora';

  @override
  String get dailyRitualAnswerLabel => 'Sua resposta';

  @override
  String get dailyRitualContinue => 'Continuar';

  @override
  String get dailyRitualFinish => 'Concluir';

  @override
  String get dailyRitualEmotionalState => 'Estado emocional';

  @override
  String get dailyRitualDayNeed => 'Necessidade do dia';

  @override
  String get dailyRitualChosenIntention => 'Intenção escolhida';

  @override
  String get dailyRitualChosenMicroAction => 'Microação escolhida';

  @override
  String get dailyRitualBackHome => 'Voltar para Início';

  @override
  String get dailyRitualMorningQuestionState => 'Como você está agora?';

  @override
  String get dailyRitualMorningQuestionNeed => 'O que você mais precisa hoje?';

  @override
  String get dailyRitualMorningQuestionIntention =>
      'Qual intenção quer carregar hoje?';

  @override
  String get dailyRitualMorningQuestionAction =>
      'Qual pequeno passo consegue dar hoje?';

  @override
  String get dailyRitualEveningQuestionState => 'Como você está agora?';

  @override
  String get dailyRitualEveningQuestionNeed =>
      'O que você mais precisa soltar hoje?';

  @override
  String get dailyRitualEveningQuestionIntention =>
      'Qual intenção quer levar para o descanso?';

  @override
  String get dailyRitualEveningQuestionAction =>
      'Qual pequeno cuidado consegue fazer agora?';

  @override
  String get careLoadingSecureAccess => 'Carregando acesso seguro...';

  @override
  String get careLoadErrorTitle => 'Não foi possível carregar o Evolua Care';

  @override
  String get careLoadErrorMessage =>
      'Verifique sua conexão e tente novamente em instantes.';

  @override
  String get careRecommendationsLoading =>
      'Carregando orientações do terapeuta...';

  @override
  String get careRecommendationsError =>
      'Não foi possível carregar as orientações agora.';

  @override
  String get careRecommendationsTitle => 'Orientações do terapeuta';

  @override
  String get careRecommendationsSubtitle =>
      'Recomendações e anexos recebidos por acesso seguro.';

  @override
  String get careRecommendationsEmpty =>
      'Nenhuma orientação recebida por enquanto.';

  @override
  String get careTherapistFallback => 'Terapeuta';

  @override
  String get careAcknowledgeReading => 'Confirmar leitura';

  @override
  String get carePreparingAccess => 'Preparando acesso seguro...';

  @override
  String get careShareTitle => 'Compartilhe com seu terapeuta';

  @override
  String get careShareMessage =>
      'Gere um acesso temporário para que seu terapeuta veja um relatório protegido da sua jornada emocional.';

  @override
  String get careGenerateSecureAccess => 'Gerar acesso seguro';

  @override
  String get careExpiredTitle => 'Sessão expirada';

  @override
  String get careExpiredMessage =>
      'O acesso temporário venceu. Gere um novo código quando estiver com seu terapeuta.';

  @override
  String get careGenerateNewAccess => 'Gerar novo acesso';

  @override
  String get careRevokedTitle => 'Acesso revogado';

  @override
  String get careRevokedMessage =>
      'Seu terapeuta não pode mais acessar essa sessão compartilhada.';

  @override
  String get careQrMissing =>
      'Por segurança, gere um novo acesso para exibir o QR Code completo.';

  @override
  String get careTemporaryCode => 'Código temporário';

  @override
  String careExpiresAt(Object value) {
    return 'Expira em $value';
  }

  @override
  String get careCodeCopied => 'Código copiado com segurança.';

  @override
  String get careCopyCode => 'Copiar código';

  @override
  String get careFullLinkCopied => 'Link completo copiado com segurança.';

  @override
  String get careCopyFullLink => 'Copiar link completo';

  @override
  String get careRevokeAccess => 'Revogar acesso';

  @override
  String get careConnectedTitle => 'Conectado ao terapeuta';

  @override
  String get careActiveTitle => 'Acesso temporário ativo';

  @override
  String get careConnectedMessage =>
      'Seu terapeuta validou o acesso. Você pode revogar quando quiser.';

  @override
  String get careActiveMessage =>
      'Mostre o QR Code ou o código ao seu terapeuta somente durante a consulta.';

  @override
  String get careHistoryLoading => 'Carregando histórico de conexões...';

  @override
  String get careHistoryError =>
      'Não foi possível carregar o histórico agora. Tente novamente mais tarde.';

  @override
  String get careHistoryTitle => 'Histórico de conexões';

  @override
  String get careHistorySubtitle =>
      'Acompanhe os acessos temporários criados para atendimento.';

  @override
  String get careHistoryEmpty => 'Nenhuma conexão anterior por enquanto.';

  @override
  String careHistoryTile(Object status, Object date) {
    return 'Sessão com terapeuta $status em $date';
  }

  @override
  String get careStatusConnected => 'conectada';

  @override
  String get careStatusRevoked => 'revogada';

  @override
  String get careStatusExpired => 'expirada';

  @override
  String get careStatusActive => 'ativa';

  @override
  String get careStatusRegistered => 'registrada';
}

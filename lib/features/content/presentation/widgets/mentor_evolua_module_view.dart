import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/ai_quota_limit_card.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/monetization_prompt.dart';
import 'package:evolua_frontend/features/content/application/journey_chat_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_message.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_reply.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/panel_skeleton.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MentorEvoluaModuleView extends ConsumerWidget {
  const MentorEvoluaModuleView({
    super.key,
    required this.onOpenTrails,
    this.onOpenPremium,
  });

  final VoidCallback onOpenTrails;
  final VoidCallback? onOpenPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentJourney = ref.watch(currentJourneyTrailProvider);
    final currentSubscription = ref
        .watch(subscriptionControllerProvider)
        .asData
        ?.value
        .current;
    final premium = currentSubscription?.premium ?? false;

    return currentJourney.when(
      data: (trail) => Column(
        children: [
          _MentorHeader(trail: trail, onOpenTrails: onOpenTrails),
          const SizedBox(height: 16),
          if (!premium)
            _MentorPremiumGate(onOpenPremium: onOpenPremium)
          else ...[
            _MentorPremiumGate(onOpenPremium: onOpenPremium),
            const SizedBox(height: 16),
            MentorEvoluaChatCard(trail: trail, onOpenPremium: onOpenPremium),
          ],
        ],
      ),
      error: (_, _) => Column(
        children: [
          _MentorHeader(trail: null, onOpenTrails: onOpenTrails),
          const SizedBox(height: 16),
          if (!premium)
            _MentorPremiumGate(onOpenPremium: onOpenPremium)
          else ...[
            _MentorPremiumGate(onOpenPremium: onOpenPremium),
            const SizedBox(height: 16),
            MentorEvoluaChatCard(trail: null, onOpenPremium: onOpenPremium),
          ],
        ],
      ),
      loading: () => const PanelSkeleton(rows: 4, tileHeight: 92),
    );
  }
}

class _MentorHeader extends StatelessWidget {
  const _MentorHeader({required this.trail, required this.onOpenTrails});

  final Trail? trail;
  final VoidCallback onOpenTrails;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Mentor Evolua',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentGold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mentor Evolua',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: context.evoluaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            trail == null
                ? 'Converse para clarear seu momento, adaptar proximos passos e encontrar uma direcao leve antes de escolher uma trilha.'
                : 'Seu mentor usa a trilha ativa como contexto para adaptar etapas, destravar exercicios e manter o ritmo praticavel.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (trail != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: context.evoluaColors.surfaceStrong.withValues(
                  alpha: 0.42,
                ),
                border: Border.all(
                  color: context.evoluaColors.outline.withValues(alpha: 0.24),
                ),
              ),
              child: Text(
                'Contexto ativo: ${trail!.title}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.evoluaColors.textPrimary,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onOpenTrails,
              icon: const Icon(Icons.auto_stories_rounded),
              label: const Text('Abrir Trilhas'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MentorPremiumGate extends ConsumerWidget {
  const _MentorPremiumGate({this.onOpenPremium});

  final VoidCallback? onOpenPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionControllerProvider);
    final current = subscriptionState.asData?.value.current;
    final premium = current?.premium ?? false;

    final title = premium
        ? 'Mentoria premium liberada'
        : 'Conteúdos exclusivos de mentoria';
    final subtitle = premium
        ? 'Seu plano Premium já libera os conteúdos completos de mentoria, sem anúncios.'
        : 'O Mentor Evolua faz parte do Premium para oferecer acompanhamento mais profundo, sem anúncios e com mais continuidade.';

    return PrimaryPanel(
      semanticLabel: 'Passe diario de mentoria',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: AppColors.accentGold.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.evoluaColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!premium) ...[
            const SizedBox(height: 14),
            SoftPremiumPrompt(
              title: 'Mentor disponível no Premium',
              message:
                  'Você pode continuar sua jornada pelas trilhas gratuitas. O Premium abre o Mentor para adaptar etapas, aprofundar leituras e manter sua evolução com mais contexto.',
              benefit:
                  'Premium libera Mentor Evolua, trilhas premium, Espelho avançado, histórico completo e uma experiência sem anúncios.',
              onOpenPremium: onOpenPremium,
              primaryLabel: 'Evoluir com Premium',
              secondaryLabel: 'Continuar nas trilhas gratuitas',
            ),
          ],
        ],
      ),
    );
  }
}

class MentorEvoluaChatCard extends ConsumerStatefulWidget {
  const MentorEvoluaChatCard({
    super.key,
    required this.trail,
    this.onOpenPremium,
  });

  final Trail? trail;
  final VoidCallback? onOpenPremium;

  @override
  ConsumerState<MentorEvoluaChatCard> createState() =>
      _MentorEvoluaChatCardState();
}

class _MentorEvoluaChatCardState extends ConsumerState<MentorEvoluaChatCard> {
  final _messageController = TextEditingController();
  late final List<JourneyChatMessage> _messages = [
    JourneyChatMessage(
      role: 'assistant',
      content: widget.trail == null
          ? 'Estou aqui para pensar com voce. Me conte como esta seu momento ou que tipo de proximo passo faria sentido hoje.'
          : 'Estou aqui para conversar sobre sua jornada. Me conte onde voce travou ou qual exercicio quer adaptar para hoje.',
    ),
  ];
  bool _isSending = false;
  bool _isRewardLoading = false;
  String? _error;
  JourneyChatReply? _quotaLimitedReply;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    final conversationHistory = _messages.length > 6
        ? _messages.sublist(_messages.length - 6)
        : List.of(_messages);

    setState(() {
      _isSending = true;
      _error = null;
      _messages.add(JourneyChatMessage(role: 'user', content: text));
      _messageController.clear();
    });

    try {
      final reply = await ref
          .read(journeyChatControllerProvider)
          .send(
            message: text,
            conversationHistory: conversationHistory,
            trailId: widget.trail?.id,
          );

      if (!mounted) {
        return;
      }

      final suggestedStep = reply.suggestedNextStep.trim();
      setState(() {
        _quotaLimitedReply = reply.quotaLimited ? reply : null;
        _messages.add(
          JourneyChatMessage(
            role: 'assistant',
            content: suggestedStep.isEmpty
                ? reply.reply
                : '${reply.reply}\n\nProximo passo: $suggestedStep',
          ),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is DioException
          ? (error.response?.data is Map<String, dynamic>
                ? (error.response?.data['message']?.toString() ??
                      error.message ??
                      'Nao conseguimos responder agora.')
                : error.message ?? 'Nao conseguimos responder agora.')
          : 'Nao conseguimos responder agora.';
      setState(() => _error = message);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _watchRewardedAd() async {
    if (_isRewardLoading) {
      return;
    }

    setState(() => _isRewardLoading = true);
    try {
      final rewarded = await ref
          .read(rewardedAdServiceProvider)
          .showRewardedAd(rewardType: 'AI_ACTION');
      if (!mounted) {
        return;
      }
      await ref.read(subscriptionControllerProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: rewarded
            ? 'Crédito extra de IA liberado. Envie uma nova mensagem ao Mentor.'
            : context.l10n.errorRewardedAdUnavailable,
        icon: rewarded
            ? Icons.ondemand_video_rounded
            : Icons.workspace_premium_rounded,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: context.l10n.errorRewardedAdUnavailable,
        icon: Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isRewardLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Conversa com Mentor Evolua',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversa guiada',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.evoluaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'O Mentor Evolua responde com passos pequenos e adaptacoes praticas, sem substituir apoio profissional.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                children: _messages
                    .map(
                      (message) => Align(
                        alignment: message.role == 'user'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.role == 'user'
                                ? AppColors.accent.withValues(alpha: 0.16)
                                : context.evoluaColors.surface.withValues(
                                    alpha: 0.72,
                                  ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: context.evoluaColors.outline.withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          child: Text(
                            message.content,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.evoluaColors.textPrimary,
                                ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
          if (_quotaLimitedReply != null) ...[
            const SizedBox(height: 8),
            AiQuotaLimitCard(
              message: _quotaLimitedReply!.limitMessage,
              rewardedAdAvailable: _quotaLimitedReply!.rewardedAdAvailable,
              upgradeRecommended: _quotaLimitedReply!.upgradeRecommended,
              isRewardLoading: _isRewardLoading,
              onWatchRewardedAd: _watchRewardedAd,
              onOpenPremium: widget.onOpenPremium,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 3,
                  enabled: !_isSending,
                  decoration: const InputDecoration(
                    labelText: 'Pergunte ou peca uma adaptacao',
                    hintText:
                        'Ex: como eu faco esse exercicio com pouco tempo?',
                    prefixIcon: Icon(Icons.forum_rounded),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

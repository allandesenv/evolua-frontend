import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionModuleView extends ConsumerStatefulWidget {
  const SubscriptionModuleView({super.key});

  @override
  ConsumerState<SubscriptionModuleView> createState() =>
      _SubscriptionModuleViewState();
}

class _SubscriptionModuleViewState
    extends ConsumerState<SubscriptionModuleView> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(subscriptionControllerProvider, (previous, next) {
      final data = next.asData?.value;
      if (data?.message case final message?) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        ref.read(subscriptionControllerProvider.notifier).clearMessage();
      }

      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível processar a assinatura agora. Tente novamente em instantes.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _startCheckout(PlanView plan) async {
    try {
      final checkout = await ref
          .read(subscriptionControllerProvider.notifier)
          .startPremiumCheckout(plan);
      final url = checkout.checkoutUrl;
      if (url != null && url.isNotEmpty) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_self',
        );
      }
    } on SubscriptionCheckoutException {
      // O controller já publicou uma mensagem amigável e reabilitou os botões.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionControllerProvider);
    return state.when(
      loading: () => const PrimaryPanel(child: LinearProgressIndicator()),
      error: (error, stackTrace) => PrimaryPanel(
        child: Text(
          'Não foi possível carregar os planos agora.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      data: (data) {
        final current = data.current;
        final plans = [...data.plans]
          ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
        final essential = plans.firstWhere(
          (plan) => !plan.premium,
          orElse: () => const PlanView(
            planCode: 'essential-free',
            title: 'Essencial',
            subtitle:
                'Comece sua jornada de autoconhecimento com leveza e constância.',
            billingCycle: 'MONTHLY',
            premium: false,
            price: 0,
            currency: 'BRL',
            benefits: [
              'Check-ins emocionais ilimitados',
              'Diário e reflexões pessoais',
              'Trilhas gratuitas de desenvolvimento',
              'Insights básicos com IA',
              '1 leitura emocional aprofundada por dia',
              'Histórico emocional dos últimos 30 dias',
              'Espelho da Evolução resumido',
            ],
            active: true,
          ),
        );
        final premiumPlans = plans.where((plan) => plan.premium).toList();
        final cards = [
          _PlanCard(
            title: essential.title,
            subtitle: essential.subtitle,
            bullets: essential.benefits,
            accent: AppColors.accentWarm,
            highlighted: current?.premium != true,
            cta: 'Plano atual',
            disabled: true,
          ),
          ...premiumPlans.map((plan) {
            final active =
                current?.planCode == plan.planCode && current?.premium == true;
            return _PlanCard(
              title: plan.title,
              subtitle: plan.subtitle,
              priceLabel: plan.billingCycle == 'YEARLY'
                  ? '${_formatPrice(plan.price, plan.currency)}/ano'
                  : '${_formatPrice(plan.price, plan.currency)}/mês',
              bullets: plan.benefits,
              accent: _accentForPlan(plan),
              badge:
                  plan.badge ??
                  (plan.billingCycle == 'YEARLY' ? 'Economize 33%' : null),
              availabilityNote: plan.availabilityNote,
              featured: plan.highlighted || plan.isFounder,
              highlighted: active,
              cta: data.isBusy ? 'Processando...' : _ctaForPlan(plan, current),
              disabled: data.isBusy || active,
              onTap: () => _startCheckout(plan),
            );
          }),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrimaryPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planos e assinaturas',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    current?.premium == true
                        ? 'Seu ${_currentPlanLabel(current!, plans)} está ativo. Você aprofunda sua jornada sem anúncios e com mais contexto emocional.'
                        : 'Você está no plano Essencial. Comece sua jornada de autoconhecimento com leveza e constância.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PlanCardsLayout(cards: cards),
          ],
        );
      },
    );
  }

  String _formatPrice(double price, String currency) {
    if (price == 0) {
      return 'Grátis';
    }
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Color _accentForPlan(PlanView plan) {
    return plan.isFounder ? AppColors.accent : AppColors.accentGold;
  }

  String _ctaForPlan(PlanView plan, CurrentSubscription? current) {
    if (current?.planCode == plan.planCode && current?.premium == true) {
      return 'Plano ativo';
    }
    if (plan.isFounder) {
      return 'Apoiar como fundador';
    }
    return plan.billingCycle == 'YEARLY'
        ? 'Evoluir continuamente'
        : 'Aprofundar jornada';
  }

  String _currentPlanLabel(CurrentSubscription current, List<PlanView> plans) {
    for (final plan in plans) {
      if (plan.planCode == current.planCode) {
        return plan.title;
      }
    }
    return current.premium ? 'Premium' : 'Essencial';
  }
}

class _PlanCardsLayout extends StatelessWidget {
  const _PlanCardsLayout({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        final columns = constraints.maxWidth >= 1120 ? 3 : 2;
        final spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.accent,
    required this.cta,
    this.priceLabel,
    this.badge,
    this.availabilityNote,
    this.featured = false,
    this.highlighted = false,
    this.disabled = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final List<String> bullets;
  final Color accent;
  final String cta;
  final String? priceLabel;
  final String? badge;
  final String? availabilityNote;
  final bool featured;
  final bool highlighted;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: featured ? 0.22 : 0.16),
              borderRadius: BorderRadius.circular(14),
              border: featured
                  ? Border.all(color: accent.withValues(alpha: 0.38))
                  : null,
            ),
            child: Icon(Icons.workspace_premium_rounded, color: accent),
          ),
          const SizedBox(height: 16),
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.36)),
              ),
              child: Text(
                badge!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (priceLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              priceLabel!,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_rounded, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(bullet)),
                ],
              ),
            ),
          ),
          if (availabilityNote != null && availabilityNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              availabilityNote!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: disabled ? null : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: highlighted ? accent : AppColors.surfaceStrong,
                foregroundColor: highlighted
                    ? AppColors.background
                    : AppColors.textPrimary,
              ),
              child: Text(cta),
            ),
          ),
        ],
      ),
    );
  }
}

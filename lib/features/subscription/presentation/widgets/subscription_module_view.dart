import 'package:dio/dio.dart';
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
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                  ? ((error.response?.data['details'] as List?)?.join(', ') ??
                        error.message ??
                        'Nao foi possivel processar a assinatura.')
                  : error.message ?? 'Nao foi possivel processar a assinatura.')
            : 'Nao foi possivel processar a assinatura.';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  Future<void> _startCheckout(String planCode) async {
    final checkout = await ref
        .read(subscriptionControllerProvider.notifier)
        .startCheckout(planCode);
    final url = checkout.checkoutUrl;
    if (url != null && url.isNotEmpty) {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionControllerProvider);
    return state.when(
      loading: () => const PrimaryPanel(child: LinearProgressIndicator()),
      error: (error, stackTrace) => PrimaryPanel(
        child: Text(
          'Nao foi possivel carregar os planos agora.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      data: (data) {
        final current = data.current;
        final premiumPlans = data.plans.where((plan) => plan.premium).toList();
        final essential = data.plans.firstWhere(
          (plan) => !plan.premium,
          orElse: () => const PlanView(
            planCode: 'essential-free',
            title: 'Essencial',
            subtitle: 'Base gratuita do app.',
            billingCycle: 'MONTHLY',
            premium: false,
            price: 0,
            currency: 'BRL',
            benefits: ['Base gratuita'],
            active: true,
          ),
        );

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
                        ? 'Seu premium esta ativo e a liberacao depende sempre da confirmacao real do pagamento.'
                        : 'Voce esta no plano essencial. Quando quiser aprofundar a jornada, o upgrade leva voce para o checkout seguro e so libera o premium apos confirmacao.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  _CurrentPlanCard(current: current, pending: data.pendingCheckout),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final cards = [
                  _PlanCard(
                    title: essential.title,
                    subtitle: essential.subtitle,
                    bullets: essential.benefits,
                    accent: AppColors.accentWarm,
                    highlighted: current?.premium != true,
                    cta: current?.premium == true
                        ? 'Voltar ao essencial'
                        : 'Plano atual',
                    disabled: data.isBusy || current?.premium != true,
                    onTap: current?.premium == true
                        ? () => ref
                              .read(subscriptionControllerProvider.notifier)
                              .cancelPremium()
                        : null,
                  ),
                  ...premiumPlans.map(
                    (plan) => _PlanCard(
                      title: plan.title,
                      subtitle:
                          '${plan.subtitle} ${_formatPrice(plan.price, plan.currency)}/${plan.billingCycle == 'YEARLY' ? 'ano' : 'mes'}',
                      bullets: plan.benefits,
                      accent: AppColors.accentGold,
                      highlighted: current?.planCode == plan.planCode,
                      cta: current?.planCode == plan.planCode &&
                              current?.premium == true
                          ? 'Plano ativo'
                          : 'Assinar agora',
                      disabled: data.isBusy ||
                          (current?.planCode == plan.planCode &&
                              current?.premium == true),
                      onTap: () => _startCheckout(plan.planCode),
                    ),
                  ),
                ];

                if (compact) {
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

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cards
                      .map(
                        (card) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: card,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _formatPrice(double price, String currency) {
    if (price == 0) {
      return 'Gratis';
    }
    return 'R\$ ${price.toStringAsFixed(2)}';
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.current, required this.pending});

  final CurrentSubscription? current;
  final CheckoutSession? pending;

  @override
  Widget build(BuildContext context) {
    final label = current?.premium == true ? 'Premium' : 'Essencial';
    final status = current?.status ?? 'NONE';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plano atual', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Status: $status',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (current?.currentPeriodEndsAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Proxima referencia: ${current!.currentPeriodEndsAt!.day.toString().padLeft(2, '0')}/${current!.currentPeriodEndsAt!.month.toString().padLeft(2, '0')}/${current!.currentPeriodEndsAt!.year}',
            ),
          ],
          if (pending != null) ...[
            const SizedBox(height: 12),
            Text(
              pending!.isApproved
                  ? 'Pagamento confirmado para ${pending!.planCode}.'
                  : 'Checkout ${pending!.status.toLowerCase()} para ${pending!.planCode}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
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
    this.highlighted = false,
    this.disabled = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final List<String> bullets;
  final Color accent;
  final String cta;
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
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.workspace_premium_rounded, color: accent),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
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

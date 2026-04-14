import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_skeletons.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionModuleView extends ConsumerStatefulWidget {
  const SubscriptionModuleView({super.key});

  @override
  ConsumerState<SubscriptionModuleView> createState() =>
      _SubscriptionModuleViewState();
}

class _SubscriptionModuleViewState
    extends ConsumerState<SubscriptionModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _planCodeController = TextEditingController(text: 'premium-monthly');
  String _status = 'ACTIVE';
  String _billingCycle = 'MONTHLY';
  bool _premium = true;

  @override
  void initState() {
    super.initState();
    ref.listenManual(subscriptionControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                  ? ((error.response?.data['details'] as List?)?.join(', ') ??
                        error.message ??
                        'Nao foi possivel salvar a assinatura.')
                  : error.message ?? 'Nao foi possivel salvar a assinatura.')
            : 'Nao foi possivel salvar a assinatura.';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  @override
  void dispose() {
    _planCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(subscriptionControllerProvider.notifier)
        .create(
          planCode: _planCodeController.text.trim(),
          status: _status,
          billingCycle: _billingCycle,
          premium: _premium,
        );
  }

  Future<void> _activatePlan({
    required String planCode,
    required bool premium,
  }) async {
    await ref
        .read(subscriptionControllerProvider.notifier)
        .create(
          planCode: planCode,
          status: 'ACTIVE',
          billingCycle: 'MONTHLY',
          premium: premium,
        );
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionControllerProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final isAdmin = session?.isAdmin ?? false;

    return Column(
      children: [
        subscriptionState.when(
          data: (items) {
            final current = _pickCurrent(items);
            return PrimaryPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Planos e assinaturas',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(subscriptionControllerProvider.notifier)
                            .refresh(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Atualizar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    current?.premium == true
                        ? 'Seu premium esta ativo. Voce pode renovar o acesso de teste ou revisar seus beneficios.'
                        : 'Hoje voce esta no plano essencial. Quando quiser aprofundar a experiencia, o premium libera mais conteudo e continuidade.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  _CurrentPlanCard(current: current),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final cards = [
                        _PlanCard(
                          title: 'Essencial',
                          subtitle:
                              'Base para check-ins, jornada atual e exploracao do app no seu ritmo.',
                          bullets: const [
                            'Check-in e trilha atual',
                            'Acesso ao historico principal',
                            'Reflexoes, espacos e perfil',
                          ],
                          accent: AppColors.accentWarm,
                          cta: 'Manter essencial',
                          onTap:
                              subscriptionState.isLoading &&
                                  !subscriptionState.hasValue
                              ? null
                              : () => _activatePlan(
                                  planCode: 'essential-free',
                                  premium: false,
                                ),
                        ),
                        _PlanCard(
                          title: 'Premium',
                          subtitle:
                              'Mais profundidade, acesso premium e uma experiencia de jornada ampliada.',
                          bullets: const [
                            'Trilhas premium e conteudo ampliado',
                            'Mais camadas de jornada e suporte',
                            'Upgrade e renovacao em ambiente de teste',
                          ],
                          accent: AppColors.accentGold,
                          highlighted: true,
                          cta: current?.premium == true
                              ? 'Renovar premium de teste'
                              : 'Ativar premium em teste',
                          onTap:
                              subscriptionState.isLoading &&
                                  !subscriptionState.hasValue
                              ? null
                              : () => _activatePlan(
                                  planCode: 'premium-monthly',
                                  premium: true,
                                ),
                        ),
                      ];

                      if (compact) {
                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 12),
                            cards[1],
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[1]),
                        ],
                      );
                    },
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      collapsedIconColor: AppColors.textSecondary,
                      iconColor: AppColors.textPrimary,
                      title: const Text('Ajustes tecnicos de assinatura'),
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _planCodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Plan code',
                                  prefixIcon: Icon(
                                    Icons.workspace_premium_rounded,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Informe o plano.'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _status,
                                      decoration: const InputDecoration(
                                        labelText: 'Status',
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'ACTIVE',
                                          child: Text('ACTIVE'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'PENDING',
                                          child: Text('PENDING'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _status = value);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _billingCycle,
                                      decoration: const InputDecoration(
                                        labelText: 'Ciclo',
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'MONTHLY',
                                          child: Text('MONTHLY'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'YEARLY',
                                          child: Text('YEARLY'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _billingCycle = value);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Premium ativo'),
                                value: _premium,
                                onChanged: (value) {
                                  setState(() => _premium = value);
                                },
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      subscriptionState.isLoading &&
                                          !subscriptionState.hasValue
                                      ? null
                                      : _submit,
                                  icon: const Icon(Icons.credit_card_rounded),
                                  label: const Text('Salvar assinatura'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
          error: (error, stackTrace) => PrimaryPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planos e assinaturas',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nao foi possivel carregar o centro de upgrade agora.',
                ),
              ],
            ),
          ),
          loading: () => const _SubscriptionLoadingState(),
        ),
        const SizedBox(height: 16),
        subscriptionState.when(
          data: (items) => _SubscriptionList(items: items),
          error: (error, stackTrace) => const _SubscriptionErrorState(),
          loading: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  SubscriptionRecord? _pickCurrent(List<SubscriptionRecord> items) {
    if (items.isEmpty) {
      return null;
    }

    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.firstWhere(
      (item) => item.status == 'ACTIVE',
      orElse: () => sorted.first,
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.current});

  final SubscriptionRecord? current;

  @override
  Widget build(BuildContext context) {
    final isPremium = current?.premium == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (isPremium ? AppColors.accentGold : AppColors.accentWarm)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isPremium ? AppColors.accentGold : AppColors.accentWarm)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plano atual',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            current == null
                ? 'Essencial'
                : isPremium
                ? 'Premium'
                : 'Essencial',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            current == null
                ? 'Nenhuma assinatura registrada ainda. Vamos considerar o acesso essencial como ponto de partida.'
                : 'Status ${current!.status} · ciclo ${current!.billingCycle.toLowerCase()} · ${current!.planCode}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
    required this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final List<String> bullets;
  final Color accent;
  final String cta;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong.withValues(
          alpha: highlighted ? 0.5 : 0.35,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          ...bullets.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: highlighted
                ? FilledButton(onPressed: onTap, child: Text(cta))
                : OutlinedButton(onPressed: onTap, child: Text(cta)),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionList extends StatelessWidget {
  const _SubscriptionList({required this.items});

  final List<SubscriptionRecord> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _SubscriptionEmptyState();
    }

    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: sorted
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PrimaryPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.planCode,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                        Text(
                          item.status,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.accentGold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.billingCycle} · ${item.premium ? 'Premium' : 'Essencial'}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SubscriptionLoadingState extends StatelessWidget {
  const _SubscriptionLoadingState();

  @override
  Widget build(BuildContext context) {
    return const FeedSkeleton(cards: 2);
  }
}

class _SubscriptionEmptyState extends StatelessWidget {
  const _SubscriptionEmptyState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text('Nenhuma assinatura cadastrada ainda.'),
    );
  }
}

class _SubscriptionErrorState extends StatelessWidget {
  const _SubscriptionErrorState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text(
        'Nao foi possivel carregar assinaturas.',
        style: TextStyle(color: AppColors.danger),
      ),
    );
  }
}

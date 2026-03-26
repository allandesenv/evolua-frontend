import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionModuleView extends ConsumerStatefulWidget {
  const SubscriptionModuleView({super.key});

  @override
  ConsumerState<SubscriptionModuleView> createState() => _SubscriptionModuleViewState();
}

class _SubscriptionModuleViewState extends ConsumerState<SubscriptionModuleView> {
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
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

    await ref.read(subscriptionControllerProvider.notifier).create(
          planCode: _planCodeController.text.trim(),
          status: _status,
          billingCycle: _billingCycle,
          premium: _premium,
        );
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionControllerProvider);

    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Planos e assinatura',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(subscriptionControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Modele o fluxo de monetizacao com plano, status, ciclo de cobranca e indicacao premium.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _planCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Plan code',
                        prefixIcon: Icon(Icons.workspace_premium_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe o plano.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: const InputDecoration(labelText: 'Status'),
                            items: const [
                              DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                              DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
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
                            decoration: const InputDecoration(labelText: 'Ciclo'),
                            items: const [
                              DropdownMenuItem(value: 'MONTHLY', child: Text('MONTHLY')),
                              DropdownMenuItem(value: 'YEARLY', child: Text('YEARLY')),
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
                        onPressed: subscriptionState.isLoading && !subscriptionState.hasValue
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
        ),
        const SizedBox(height: 16),
        subscriptionState.when(
          data: (items) => _SubscriptionList(items: items),
          error: (error, stackTrace) => const _SubscriptionErrorState(),
          loading: () => const _SubscriptionLoadingState(),
        ),
      ],
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

    return Column(
      children: items
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
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        Text(
                          item.status,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.accentGold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.billingCycle} · ${item.premium ? 'Premium' : 'Base'}',
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
    return const PrimaryPanel(
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Carregando assinaturas...'),
        ],
      ),
    );
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

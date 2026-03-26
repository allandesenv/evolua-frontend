import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationModuleView extends ConsumerStatefulWidget {
  const NotificationModuleView({super.key});

  @override
  ConsumerState<NotificationModuleView> createState() => _NotificationModuleViewState();
}

class _NotificationModuleViewState extends ConsumerState<NotificationModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _channel = 'EMAIL';

  @override
  void initState() {
    super.initState();
    ref.listenManual(notificationControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                    error.message ??
                    'Nao foi possivel criar a notificacao.')
                : error.message ?? 'Nao foi possivel criar a notificacao.')
            : 'Nao foi possivel criar a notificacao.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(notificationControllerProvider.notifier).create(
          channel: _channel,
          message: _messageController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsState = ref.watch(notificationControllerProvider);

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
                      'Notificacoes e lembretes',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(notificationControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Crie lembretes e comunicacoes por canal para testar o modulo de notificacoes dentro do fluxo do app.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _channel,
                      decoration: const InputDecoration(labelText: 'Canal'),
                      items: const [
                        DropdownMenuItem(value: 'EMAIL', child: Text('EMAIL')),
                        DropdownMenuItem(value: 'PUSH', child: Text('PUSH')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _channel = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notifications_active_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Escreva a mensagem.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: notificationsState.isLoading && !notificationsState.hasValue
                            ? null
                            : _submit,
                        icon: const Icon(Icons.notifications_rounded),
                        label: const Text('Criar notificacao'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        notificationsState.when(
          data: (items) => _NotificationList(items: items),
          error: (error, stackTrace) => const _NotificationErrorState(),
          loading: () => const _NotificationLoadingState(),
        ),
      ],
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({required this.items});

  final List<NotificationJob> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _NotificationEmptyState();
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
                            item.channel,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.mark_email_read_rounded,
                          color: AppColors.accentWarm,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(item.message, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _NotificationLoadingState extends StatelessWidget {
  const _NotificationLoadingState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Carregando notificacoes...'),
        ],
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text('Nenhuma notificacao criada ainda.'),
    );
  }
}

class _NotificationErrorState extends StatelessWidget {
  const _NotificationErrorState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text(
        'Nao foi possivel carregar notificacoes.',
        style: TextStyle(color: AppColors.danger),
      ),
    );
  }
}

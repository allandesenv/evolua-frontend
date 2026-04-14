import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationInboxControllerProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notificacoes',
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (context) => const _NotificationInboxDialog(),
            );
          },
          icon: Icon(
            unreadCount > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 4,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (notificationsState.isLoading && !notificationsState.hasValue)
          const Positioned(
            right: -2,
            bottom: -2,
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

class NotificationAdminConsole extends ConsumerStatefulWidget {
  const NotificationAdminConsole({super.key});

  @override
  ConsumerState<NotificationAdminConsole> createState() =>
      _NotificationAdminConsoleState();
}

class _NotificationAdminConsoleState
    extends ConsumerState<NotificationAdminConsole> {
  final _formKey = GlobalKey<FormState>();
  final _targetUserIdController = TextEditingController();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _actionTargetController = TextEditingController(text: '/home');
  String _type = 'ADMIN_MESSAGE';

  @override
  void initState() {
    super.initState();
    ref.listenManual(notificationInboxControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                  ? ((error.response?.data['details'] as List?)?.join(', ') ??
                        error.message ??
                        'Nao foi possivel enviar a notificacao.')
                  : error.message ?? 'Nao foi possivel enviar a notificacao.')
            : 'Nao foi possivel enviar a notificacao.';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  @override
  void dispose() {
    _targetUserIdController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    _actionTargetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(notificationInboxControllerProvider.notifier)
        .createAdmin(
          targetUserId: _targetUserIdController.text.trim(),
          type: _type,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          actionTarget: _actionTargetController.text.trim().isEmpty
              ? null
              : _actionTargetController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    _titleController.clear();
    _messageController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Notificacao enviada.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationInboxControllerProvider);

    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Central admin de notificacoes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Envie notificacoes manuais para um usuario especifico usando o userId. Exemplos locais: `leo-respiro` e `clara-rocha`.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _targetUserIdController,
                  decoration: const InputDecoration(
                    labelText: 'User ID de destino',
                    prefixIcon: Icon(Icons.person_search_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe o userId do usuario.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'ADMIN_MESSAGE',
                      child: Text('Comunicacao manual'),
                    ),
                    DropdownMenuItem(
                      value: 'EVENT',
                      child: Text('Evento relevante'),
                    ),
                    DropdownMenuItem(
                      value: 'CHECKIN_REMINDER',
                      child: Text('Lembrete de check-in'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _type = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titulo',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe o titulo.'
                      : null,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _actionTargetController,
                  decoration: const InputDecoration(
                    labelText: 'Destino no app',
                    prefixIcon: Icon(Icons.alt_route_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: state.isLoading && !state.hasValue
                        ? null
                        : _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Enviar notificacao'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationInboxDialog extends ConsumerWidget {
  const _NotificationInboxDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationInboxControllerProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notificacoes',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(notificationInboxControllerProvider.notifier)
                        .markAllAsRead(),
                    child: const Text('Marcar todas como lidas'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Lembretes de check-in, eventos relevantes e mensagens enviadas pelo app aparecem aqui.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: notificationsState.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma notificacao por enquanto.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, unused) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return InkWell(
                          onTap: () async {
                            if (!item.isRead) {
                              await ref
                                  .read(
                                    notificationInboxControllerProvider
                                        .notifier,
                                  )
                                  .markAsRead(item.id);
                            }
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: item.isRead
                                  ? AppColors.surface
                                  : AppColors.surfaceStrong.withValues(
                                      alpha: 0.78,
                                    ),
                              border: Border.all(
                                color: item.isRead
                                    ? AppColors.outline.withValues(alpha: 0.2)
                                    : AppColors.accent.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    if (!item.isRead)
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.message,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _NotificationPill(
                                      label: _typeLabel(item.type),
                                    ),
                                    _NotificationPill(
                                      label: _timeLabel(item.createdAt),
                                    ),
                                    if (item.source == 'ADMIN')
                                      const _NotificationPill(
                                        label: 'Enviada pelo admin',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  error: (error, stackTrace) => const Center(
                    child: Text('Nao foi possivel carregar notificacoes.'),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'CHECKIN_REMINDER' => 'Lembrete de check-in',
      'EVENT' => 'Evento relevante',
      _ => 'Mensagem',
    };
  }

  String _timeLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _NotificationPill extends StatelessWidget {
  const _NotificationPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.surfaceStrong.withValues(alpha: 0.7),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

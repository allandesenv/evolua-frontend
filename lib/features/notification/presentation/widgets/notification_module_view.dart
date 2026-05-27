import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          tooltip: 'Notificações',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_notificationErrorMessage(next.error))),
        );
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
    ).showSnackBar(const SnackBar(content: Text('Notificação enviada.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationInboxControllerProvider);

    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Central admin de notificações',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Envie notificações manuais para um usuário específico usando o userId. Exemplos locais: `leo-respiro` e `clara-rocha`.',
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
                      ? 'Informe o userId do usuário.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'ADMIN_MESSAGE',
                      child: Text('Comunicação manual'),
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
                    labelText: 'Título',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe o título.'
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
                    label: const Text('Enviar notificação'),
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

String _notificationErrorMessage(Object? error) {
  const fallback = 'Não foi possível enviar a notificação agora.';
  if (error is! DioException) {
    return fallback;
  }
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    final details = data['details'];
    if (details is List && details.isNotEmpty) {
      final first = details.first.toString();
      return _isTechnicalNotificationMessage(first) ? fallback : first;
    }
    final message = data['message'];
    if (message != null) {
      final text = message.toString();
      return _isTechnicalNotificationMessage(text) ? fallback : text;
    }
  }
  return fallback;
}

bool _isTechnicalNotificationMessage(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('dioexception') ||
      normalized.contains('forbidden') ||
      normalized.contains('stacktrace') ||
      normalized.contains('exception') ||
      normalized.contains('bad request') ||
      normalized.contains('401') ||
      normalized.contains('403') ||
      normalized.contains('500');
}

class _NotificationInboxDialog extends ConsumerWidget {
  const _NotificationInboxDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationInboxControllerProvider);
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.width < 520;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 16 : 24,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: mediaQuery.size.height - (compact ? 32 : 48),
        ),
        child: PrimaryPanel(
          padding: EdgeInsets.all(compact ? 18 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 260,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Notificações',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        if (compact)
                          IconButton(
                            tooltip: 'Fechar',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                  ),
                  if (!compact)
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  TextButton.icon(
                    onPressed: notificationsState.hasValue
                        ? () => ref
                              .read(
                                notificationInboxControllerProvider.notifier,
                              )
                              .markAllAsRead()
                        : null,
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Marcar todas como lidas'),
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
                      return const SingleChildScrollView(
                        child: _NotificationEmptyState(),
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
                            final actionTarget = item.actionTarget;
                            if (context.mounted &&
                                actionTarget != null &&
                                actionTarget.isNotEmpty) {
                              Navigator.of(context).maybePop();
                              context.push(actionTarget);
                            }
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: EdgeInsets.all(compact ? 14 : 16),
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
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
                                  softWrap: true,
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
                    child: Text('Não foi possível carregar notificações.'),
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
      NotificationInboxController.carePrescriptionType => 'Evolua Care',
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

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Nenhuma notificação por enquanto',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Quando houver lembretes ou avisos importantes, eles aparecerão aqui.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
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

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/future_message/presentation/future_message_delivery_label.dart';
import 'package:evolua_frontend/features/ads/presentation/widgets/monetization_prompt.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FutureMessagesPage extends StatelessWidget {
  const FutureMessagesPage({
    super.key,
    this.initialMessageId,
    this.onOpenPremium,
  });

  final int? initialMessageId;
  final VoidCallback? onOpenPremium;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      resizeToAvoidBottomInset: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveBreakpoints.pagePadding(context),
          vertical: 16,
        ),
        child: FutureMessagesView(
          initialMessageId: initialMessageId,
          onOpenPremium: onOpenPremium,
        ),
      ),
    );
  }
}

class FutureMessagesView extends ConsumerStatefulWidget {
  const FutureMessagesView({
    super.key,
    this.initialMessageId,
    this.onOpenPremium,
  });

  final int? initialMessageId;
  final VoidCallback? onOpenPremium;

  @override
  ConsumerState<FutureMessagesView> createState() => _FutureMessagesViewState();
}

class _FutureMessagesViewState extends ConsumerState<FutureMessagesView> {
  final _bodyController = TextEditingController();
  final _rememberController = TextEditingController();
  final _feelingController = TextEditingController();
  final _hopeController = TextEditingController();
  String _triggerType = 'AFTER_DAYS';
  int _afterDays = 30;
  DateTime? _specificDate;
  int? _selectedMessageId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMessageId = widget.initialMessageId;
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _rememberController.dispose();
    _feelingController.dispose();
    _hopeController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final subscription = ref.read(currentSubscriptionProvider).asData?.value;
    final messages = ref.read(futureMessageControllerProvider).asData?.value;
    final activeCount =
        messages?.result.items.where((item) => item.isScheduled).length ?? 0;
    if (subscription?.premium != true && activeCount >= 3) {
      AppSnackBar.show(
        context,
        message:
            'No plano gratuito, você pode manter até 3 cartas ativas. O Premium libera cartas ilimitadas.',
        icon: Icons.workspace_premium_rounded,
      );
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Escreva uma mensagem para o seu futuro.',
        icon: Icons.edit_note_rounded,
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final created = await ref
          .read(futureMessageControllerProvider.notifier)
          .create(
            FutureMessageDraft(
              title: 'Carta para mim mesmo',
              body: _bodyController.text.trim(),
              promptRemember: _rememberController.text.trim(),
              promptFeeling: _feelingController.text.trim(),
              promptHope: _hopeController.text.trim(),
              triggerType: _triggerType,
              triggerConfig: _triggerConfig(),
            ),
          );
      if (!mounted) {
        return;
      }
      _bodyController.clear();
      _rememberController.clear();
      _feelingController.clear();
      _hopeController.clear();
      AppSnackBar.show(
        context,
        message: 'Sua carta foi guardada para o momento certo.',
        icon: Icons.mark_email_read_rounded,
      );
      setState(() => _selectedMessageId = created.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: _friendlyError(error),
        icon: Icons.info_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Map<String, dynamic> _triggerConfig() {
    return switch (_triggerType) {
      'AFTER_DAYS' => {'days': _afterDays},
      'SPECIFIC_DATE' => {
        'date': _formatDate(
          _specificDate ?? DateTime.now().add(const Duration(days: 30)),
        ),
      },
      'LOW_ENERGY_CHECKIN' => {'energyMax': 3},
      'BAD_DAY_STREAK' => {'days': 2, 'energyMax': 3},
      'HIGH_ANXIETY' => {'energyMax': 5},
      'INACTIVITY_AFTER_DAYS' || 'RETURN_AFTER_DAYS' => {'days': 5},
      _ => const {},
    };
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _specificDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(futureMessageControllerProvider);
    final subscription = ref.watch(currentSubscriptionProvider).asData?.value;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FutureMessagesHeader(onBack: () => context.go('/home')),
              const SizedBox(height: 16),
              if (_selectedMessageId != null) ...[
                _FutureMessageDetailPanel(
                  messageId: _selectedMessageId!,
                  onClose: () => setState(() => _selectedMessageId = null),
                ),
                const SizedBox(height: 16),
              ],
              _FutureMessageComposer(
                bodyController: _bodyController,
                rememberController: _rememberController,
                feelingController: _feelingController,
                hopeController: _hopeController,
                triggerType: _triggerType,
                afterDays: _afterDays,
                specificDate: _specificDate,
                isSubmitting: _isSubmitting,
                onTriggerChanged: (value) =>
                    setState(() => _triggerType = value),
                onAfterDaysChanged: (value) =>
                    setState(() => _afterDays = value),
                onPickDate: _pickDate,
                onSubmit: _create,
              ),
              state.maybeWhen(
                data: (data) {
                  final activeCount = data.result.items
                      .where((item) => item.isScheduled)
                      .length;
                  if (subscription?.premium == true || activeCount < 3) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SoftPremiumPrompt(
                      title: 'Cartas ilimitadas no Premium',
                      message:
                          'Você já tem 3 cartas ativas no plano gratuito. Suas cartas continuam guardadas e serão entregues no momento certo.',
                      benefit:
                          'Premium libera cartas ilimitadas para você conversar com versões futuras de si mesmo sem apagar nada.',
                      onOpenPremium: _openPremium,
                      primaryLabel: 'Assinar Premium',
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              state.when(
                data: (data) => _FutureMessageLists(
                  state: data,
                  onOpen: (id) => setState(() => _selectedMessageId = id),
                ),
                loading: () =>
                    const PrimaryPanel(child: LinearProgressIndicator()),
                error: (error, stackTrace) => PrimaryPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nao foi possivel carregar suas cartas agora.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.invalidate(futureMessageControllerProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Atualizar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  void _openPremium() {
    final callback = widget.onOpenPremium;
    if (callback != null) {
      callback();
      return;
    }
    context.go('/home?profileSection=plans');
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final details = data['details'];
        if (details is List && details.isNotEmpty) {
          return details.first.toString();
        }
      }
    }
    return 'Nao foi possivel guardar sua carta agora.';
  }
}

class _FutureMessagesHeader extends StatelessWidget {
  const _FutureMessagesHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: 'Mensagens do seu eu anterior',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Voltar para Inicio',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mensagens do seu eu anterior',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Um lugar privado para escrever cartas ao futuro, receber no momento certo e perceber como suas versoes mudam com o tempo.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _FutureMessageComposer extends StatelessWidget {
  const _FutureMessageComposer({
    required this.bodyController,
    required this.rememberController,
    required this.feelingController,
    required this.hopeController,
    required this.triggerType,
    required this.afterDays,
    required this.specificDate,
    required this.isSubmitting,
    required this.onTriggerChanged,
    required this.onAfterDaysChanged,
    required this.onPickDate,
    required this.onSubmit,
  });

  final TextEditingController bodyController;
  final TextEditingController rememberController;
  final TextEditingController feelingController;
  final TextEditingController hopeController;
  final String triggerType;
  final int afterDays;
  final DateTime? specificDate;
  final bool isSubmitting;
  final ValueChanged<String> onTriggerChanged;
  final ValueChanged<int> onAfterDaysChanged;
  final VoidCallback onPickDate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nova carta para mim mesmo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Antes de escrever, localize o que voce quer preservar deste momento.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _GuidedQuestionField(
            controller: rememberController,
            label: 'O que voce gostaria de lembrar no futuro?',
          ),
          const SizedBox(height: 12),
          _GuidedQuestionField(
            controller: feelingController,
            label: 'O que voce esta sentindo agora?',
          ),
          const SizedBox(height: 12),
          _GuidedQuestionField(
            controller: hopeController,
            label: 'O que voce espera de voce daqui a 30 dias?',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: bodyController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Sua mensagem',
              hintText:
                  'Escreva como se estivesse conversando com voce mesmo com calma.',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: triggerType,
            decoration: const InputDecoration(
              labelText: 'Quando entregar',
              prefixIcon: Icon(Icons.flag_rounded),
            ),
            items: const [
              DropdownMenuItem(
                value: 'AFTER_DAYS',
                child: Text('Em 7 ou 30 dias'),
              ),
              DropdownMenuItem(
                value: 'SPECIFIC_DATE',
                child: Text('Em uma data especial'),
              ),
              DropdownMenuItem(
                value: 'LOW_ENERGY_CHECKIN',
                child: Text('Quando eu estiver desanimado'),
              ),
              DropdownMenuItem(
                value: 'BAD_DAY_STREAK',
                child: Text('Quando houver dias dificeis em sequencia'),
              ),
              DropdownMenuItem(
                value: 'HIGH_ANXIETY',
                child: Text('Quando a ansiedade estiver alta'),
              ),
              DropdownMenuItem(
                value: 'INACTIVITY_AFTER_DAYS',
                child: Text('Quando eu parar de usar o app'),
              ),
              DropdownMenuItem(
                value: 'RETURN_AFTER_DAYS',
                child: Text('Quando eu voltar depois de dias'),
              ),
              DropdownMenuItem(
                value: 'TRAIL_COMPLETED',
                child: Text('Quando eu concluir uma trilha'),
              ),
              DropdownMenuItem(
                value: 'MOOD_IMPROVED',
                child: Text('Quando meu humor melhorar'),
              ),
              DropdownMenuItem(
                value: 'PATTERN_CHANGED',
                child: Text('Quando um padrao mudar'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onTriggerChanged(value);
              }
            },
          ),
          if (triggerType == 'AFTER_DAYS') ...[
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 dias')),
                ButtonSegment(value: 30, label: Text('30 dias')),
              ],
              selected: {afterDays},
              onSelectionChanged: (value) => onAfterDaysChanged(value.first),
            ),
          ],
          if (triggerType == 'SPECIFIC_DATE') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                specificDate == null
                    ? 'Escolher data especial'
                    : 'Data: ${_dateLabel(specificDate!)}',
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mark_email_read_rounded),
            label: const Text('Guardar mensagem'),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _GuidedQuestionField extends StatelessWidget {
  const _GuidedQuestionField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        prefixIcon: const Icon(Icons.psychology_alt_rounded),
      ),
    );
  }
}

class _FutureMessageLists extends StatelessWidget {
  const _FutureMessageLists({required this.state, required this.onOpen});

  final FutureMessageState state;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheduled = state.result.items
        .where((item) => item.isScheduled)
        .toList();
    final ready = state.delivered.items.where((item) => !item.isRead).toList();
    final read = state.delivered.items.where((item) => item.isRead).toList();
    return Column(
      children: [
        _MessageListPanel(
          title: 'Prontas para ler',
          items: ready,
          onOpen: onOpen,
        ),
        const SizedBox(height: 16),
        _MessageListPanel(title: 'Agendadas', items: scheduled, onOpen: onOpen),
        const SizedBox(height: 16),
        _MessageListPanel(title: 'Ja lidas', items: read, onOpen: onOpen),
      ],
    );
  }
}

class _MessageListPanel extends StatelessWidget {
  const _MessageListPanel({
    required this.title,
    required this.items,
    required this.onOpen,
  });

  final String title;
  final List<FutureMessage> items;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'Nada por aqui ainda. Quando uma carta encontrar o momento certo, ela aparece aqui.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onOpen(item.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: context.evoluaColors.surfaceStrong.withValues(
                        alpha: 0.32,
                      ),
                      border: Border.all(
                        color: context.evoluaColors.outline.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.isRead
                              ? Icons.drafts_rounded
                              : Icons.mark_email_unread_rounded,
                          color: item.isRead
                              ? context.evoluaColors.textSecondary
                              : AppColors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title ?? 'Carta para mim mesmo',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                futureMessageDeliveryLabel(item),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FutureMessageDetailPanel extends ConsumerWidget {
  const _FutureMessageDetailPanel({
    required this.messageId,
    required this.onClose,
  });

  final int messageId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<FutureMessage>(
      future: ref.read(futureMessageControllerProvider.notifier).get(messageId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const PrimaryPanel(child: LinearProgressIndicator());
        }
        final message = snapshot.data!;
        final canRead = message.isDelivered;
        return PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.title ?? 'Mensagem do seu eu anterior',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _TimelineLine(message: message),
              const SizedBox(height: 16),
              if (!canRead)
                Text(
                  'Essa carta esta guardada. O Evolua vai te mostrar quando o gatilho acontecer.',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else ...[
                Text(
                  message.body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: () => ref
                          .read(futureMessageControllerProvider.notifier)
                          .react(message.id, 'STILL_MAKES_SENSE'),
                      child: const Text('Isso ainda faz sentido'),
                    ),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(futureMessageControllerProvider.notifier)
                          .react(message.id, 'WRITE_ANOTHER'),
                      child: const Text('Quero escrever outra'),
                    ),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(futureMessageControllerProvider.notifier)
                          .react(message.id, 'HELPED'),
                      child: const Text('Me ajudou'),
                    ),
                  ],
                ),
              ],
              if (canRead && !message.isRead)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextButton.icon(
                    onPressed: () => ref
                        .read(futureMessageControllerProvider.notifier)
                        .markRead(message.id),
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Marcar como lida'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({required this.message});

  final FutureMessage message;

  @override
  Widget build(BuildContext context) {
    final createdMood = message.createdContext['mood']?.toString();
    final deliveredMood = message.deliveredContext['mood']?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.28),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline emocional',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Quando escreveu: ${createdMood == null || createdMood.isEmpty ? 'momento em registro' : createdMood}.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            message.deliveredAt == null
                ? 'Entrega: ${futureMessageDeliveryLabel(message)}.'
                : 'Hoje: ${deliveredMood == null || deliveredMood.isEmpty ? 'novo contexto emocional' : deliveredMood}.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

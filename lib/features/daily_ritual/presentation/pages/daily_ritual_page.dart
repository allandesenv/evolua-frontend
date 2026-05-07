import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/layout/responsive_breakpoints.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DailyRitualPage extends StatelessWidget {
  const DailyRitualPage({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      resizeToAvoidBottomInset: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveBreakpoints.pagePadding(context),
          vertical: 16,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: DailyRitualView(type: type),
            ),
          ),
        ),
      ),
    );
  }
}

class DailyRitualView extends ConsumerStatefulWidget {
  const DailyRitualView({super.key, required this.type});

  final String type;

  @override
  ConsumerState<DailyRitualView> createState() => _DailyRitualViewState();
}

class _DailyRitualViewState extends ConsumerState<DailyRitualView> {
  final _answers = List.generate(4, (_) => TextEditingController());
  int _step = -1;
  bool _isSubmitting = false;

  bool get _isEvening => widget.type == DailyRitualType.evening;

  @override
  void dispose() {
    for (final controller in _answers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_answers.any((controller) => controller.text.trim().isEmpty)) {
      AppSnackBar.show(
        context,
        message: 'Responda as quatro etapas no seu ritmo.',
        icon: Icons.edit_note_rounded,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(dailyRitualControllerProvider.notifier)
          .create(
            DailyRitualDraft(
              localDate: DateTime.now(),
              type: widget.type,
              emotionalState: _answers[0].text.trim(),
              dayNeed: _answers[1].text.trim(),
              intention: _answers[2].text.trim(),
              microAction: _answers[3].text.trim(),
            ),
          );
      if (!mounted) {
        return;
      }
      AppSnackBar.show(
        context,
        message: _isEvening
            ? 'Fechamento salvo. Agora solte o que nao precisa carregar.'
            : 'Ritual salvo. Sua jornada diaria ja tem um norte.',
        icon: Icons.check_circle_outline_rounded,
      );
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyRitualControllerProvider);
    final copy = _DailyRitualCopy.forType(widget.type);

    return state.when(
      data: (data) {
        final existing = data.byType(widget.type);
        if (existing != null) {
          return _DailyRitualResult(copy: copy, ritual: existing);
        }
        if (_step < 0) {
          return _DailyRitualIntro(
            copy: copy,
            onStart: () => setState(() => _step = 0),
            onSkip: () => context.go('/home'),
          );
        }
        return _DailyRitualFlow(
          copy: copy,
          step: _step,
          controller: _answers[_step],
          isSubmitting: _isSubmitting,
          onBack: _step == 0 ? null : () => setState(() => _step--),
          onNext: _step == 3 ? _submit : () => setState(() => _step++),
        );
      },
      loading: () => const PrimaryPanel(child: LinearProgressIndicator()),
      error: (error, stackTrace) => PrimaryPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nao foi possivel abrir seu ritual agora.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(dailyRitualControllerProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
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
    return 'Nao foi possivel salvar seu ritual agora.';
  }
}

class _DailyRitualIntro extends StatelessWidget {
  const _DailyRitualIntro({
    required this.copy,
    required this.onStart,
    required this.onSkip,
  });

  final _DailyRitualCopy copy;
  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      semanticLabel: copy.title,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(copy.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _InfoChip(
                icon: Icons.timer_rounded,
                label: 'Dura cerca de 2 minutos',
              ),
              _InfoChip(
                icon: Icons.favorite_rounded,
                label: 'Sem certo ou errado',
              ),
              _InfoChip(icon: Icons.spa_rounded, label: 'No seu ritmo'),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Comecar agora'),
              ),
              TextButton(onPressed: onSkip, child: const Text('Agora nao')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyRitualFlow extends StatelessWidget {
  const _DailyRitualFlow({
    required this.copy,
    required this.step,
    required this.controller,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
  });

  final _DailyRitualCopy copy;
  final int step;
  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${step + 1}/4',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            copy.questions[step],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Sua resposta',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (onBack != null)
                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Voltar'),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: isSubmitting ? null : onNext,
                icon: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        step == 3
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(step == 3 ? 'Concluir' : 'Continuar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyRitualResult extends StatelessWidget {
  const _DailyRitualResult({required this.copy, required this.ritual});

  final _DailyRitualCopy copy;
  final DailyRitual ritual;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.resultTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _ResultRow(label: 'Estado emocional', value: ritual.emotionalState),
          _ResultRow(label: 'Necessidade do dia', value: ritual.dayNeed),
          _ResultRow(label: 'Intencao escolhida', value: ritual.intention),
          _ResultRow(label: 'Microacao escolhida', value: ritual.microAction),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Voltar para Home'),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w800,
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _DailyRitualCopy {
  const _DailyRitualCopy({
    required this.title,
    required this.description,
    required this.resultTitle,
    required this.questions,
  });

  final String title;
  final String description;
  final String resultTitle;
  final List<String> questions;

  static _DailyRitualCopy forType(String type) {
    if (type == DailyRitualType.evening) {
      return const _DailyRitualCopy(
        title: 'Fechamento do Dia',
        description:
            'Uma pausa curta para revisar o que pesou, reconhecer o que foi bom e soltar o que nao precisa carregar.',
        resultTitle: 'Seu fechamento de hoje esta pronto',
        questions: [
          'Como voce esta agora?',
          'O que voce mais precisa soltar hoje?',
          'Qual intencao quer levar para o descanso?',
          'Qual pequeno cuidado consegue fazer agora?',
        ],
      );
    }
    return const _DailyRitualCopy(
      title: 'Ritual do Dia',
      description:
          'Uma pausa curta para perceber como voce esta, escolher uma intencao e definir um pequeno passo possivel para hoje.',
      resultTitle: 'Seu ritual de hoje esta pronto',
      questions: [
        'Como voce esta agora?',
        'O que voce mais precisa hoje?',
        'Qual intencao quer carregar hoje?',
        'Qual pequeno passo consegue dar hoje?',
      ],
    );
  }
}

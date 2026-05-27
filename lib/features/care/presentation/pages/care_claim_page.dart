import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/care/application/care_claim_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CareClaimPage extends ConsumerWidget {
  const CareClaimPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(careClaimControllerProvider);
    ref.listen(careClaimControllerProvider, (previous, next) {
      final message = next.asData?.value.successMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    });

    return GradientScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: state.when(
                loading: () => const _CareClaimLoading(),
                error: (error, _) => _CareClaimError(error: error),
                data: (value) => _CareDashboard(state: value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CareDashboard extends ConsumerWidget {
  const _CareDashboard({required this.state});

  final CareClaimState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CareClaimHeader(state: state),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              final chart = _MoodChartPanel(checkIns: state.report.checkIns);
              final insight = _InsightPanel(report: state.report);
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: chart),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: insight),
                      ],
                    )
                  : Column(
                      children: [chart, const SizedBox(height: 20), insight],
                    );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              final rituals = _RitualAdherencePanel(
                rituals: state.report.rituals,
              );
              final form = _PrescriptionPanel(
                isSending: state.isSendingPrescription,
              );
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: rituals),
                        const SizedBox(width: 20),
                        Expanded(child: form),
                      ],
                    )
                  : Column(
                      children: [rituals, const SizedBox(height: 20), form],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _CareClaimHeader extends StatelessWidget {
  const _CareClaimHeader({required this.state});

  final CareClaimState state;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Painel clínico Evolua Care',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Relatório descriptografado localmente no navegador. O servidor não recebe a chave nem o conteúdo em texto claro.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.evoluaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (state.sessionExpiresAt != null)
            Text(
              'Expira em ${_formatDateTime(state.sessionExpiresAt!)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.accentGold,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _MoodChartPanel extends StatelessWidget {
  const _MoodChartPanel({required this.checkIns});

  final List<CareClinicalCheckIn> checkIns;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Oscilação de humor',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: checkIns.isEmpty
                ? const Center(child: Text('Sem check-ins no relatório.'))
                : CustomPaint(
                    painter: _MoodChartPainter(checkIns),
                    size: Size.infinite,
                  ),
          ),
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.report});

  final CareClinicalReport report;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights emocionais',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            report.latestInsight,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          _MetricPill(
            label: 'Check-ins no relatório',
            value: report.checkIns.length.toString(),
          ),
          const SizedBox(height: 10),
          _MetricPill(
            label: 'Rituais registrados',
            value: report.completedRituals.toString(),
          ),
        ],
      ),
    );
  }
}

class _RitualAdherencePanel extends StatelessWidget {
  const _RitualAdherencePanel({required this.rituals});

  final List<CareClinicalRitual> rituals;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assiduidade dos rituais',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          if (rituals.isEmpty)
            const Text('Nenhum ritual registrado no período do relatório.')
          else
            ...rituals
                .take(8)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_formatDate(item.localDate)} • ${item.type == DailyRitualType.evening ? 'Fechamento' : 'Ritual do dia'} • ${item.intention}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _PrescriptionPanel extends ConsumerStatefulWidget {
  const _PrescriptionPanel({required this.isSending});

  final bool isSending;

  @override
  ConsumerState<_PrescriptionPanel> createState() => _PrescriptionPanelState();
}

class _PrescriptionPanelState extends ConsumerState<_PrescriptionPanel> {
  final _formKey = GlobalKey<FormState>();
  final _stateController = TextEditingController();
  final _intentionController = TextEditingController();
  final _microActionController = TextEditingController();
  String _type = DailyRitualType.morning;

  @override
  void dispose() {
    _stateController.dispose();
    _intentionController.dispose();
    _microActionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prescrever ritual',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: DailyRitualType.morning,
                  label: Text('Manhã'),
                ),
                ButtonSegment(
                  value: DailyRitualType.evening,
                  label: Text('Noite'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: widget.isSending
                  ? null
                  : (value) => setState(() => _type = value.first),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _stateController,
              decoration: const InputDecoration(
                labelText: 'Contexto emocional',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _intentionController,
              decoration: const InputDecoration(labelText: 'Intenção'),
              validator: _required,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _microActionController,
              decoration: const InputDecoration(labelText: 'Micro-ação'),
              minLines: 2,
              maxLines: 4,
              validator: _required,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: widget.isSending ? null : _submit,
              icon: widget.isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline_rounded),
              label: Text(
                widget.isSending ? 'Enviando...' : 'Enviar ritual ao paciente',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? 'Preencha este campo.'
        : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(careClaimControllerProvider.notifier)
          .sendPrescription(
            type: _type,
            localDate: DateTime.now(),
            emotionalState: _stateController.text,
            intention: _intentionController.text,
            microAction: _microActionController.text,
          );
      _intentionController.clear();
      _microActionController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível enviar o ritual agora.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _CareClaimLoading extends StatelessWidget {
  const _CareClaimLoading();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Padding(
        padding: EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text('Abrindo acesso seguro...'),
          ],
        ),
      ),
    );
  }
}

class _CareClaimError extends StatelessWidget {
  const _CareClaimError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final copy = _CareClaimErrorCopy.fromError(error);
    return PrimaryPanel(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.accentGold,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              copy.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(copy.message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CareClaimErrorCopy {
  const _CareClaimErrorCopy({required this.title, required this.message});

  final String title;
  final String message;

  factory _CareClaimErrorCopy.fromError(Object error) {
    if (error is FormatException) {
      return const _CareClaimErrorCopy(
        title: 'Link incompleto',
        message:
            'Abra novamente pelo QR Code ou copie o link completo, incluindo a chave segura.',
      );
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 410) {
        return const _CareClaimErrorCopy(
          title: 'Acesso expirado ou revogado',
          message: 'Peça ao paciente para gerar um novo acesso seguro.',
        );
      }
      if (status == 400 || status == 404) {
        return const _CareClaimErrorCopy(
          title: 'Acesso não encontrado',
          message: 'Confira se o código pertence ao QR Code mais recente.',
        );
      }
      return const _CareClaimErrorCopy(
        title: 'Não foi possível conectar',
        message: 'Tente novamente em instantes, mantendo o link completo.',
      );
    }
    return const _CareClaimErrorCopy(
      title: 'Não foi possível abrir este acesso.',
      message:
          'Confira se o link está completo, dentro do prazo e foi aberto pelo QR Code do paciente.',
    );
  }
}

class _MoodChartPainter extends CustomPainter {
  const _MoodChartPainter(this.checkIns);

  final List<CareClinicalCheckIn> checkIns;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final points = checkIns.reversed.toList();
    if (points.isEmpty) return;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final energy = (points[index].energyLevel ?? 5).clamp(0, 10);
      final x = points.length == 1
          ? size.width / 2
          : size.width * index / (points.length - 1);
      final y = size.height - (size.height * energy / 10);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, fill);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MoodChartPainter oldDelegate) {
    return oldDelegate.checkIns != checkIns;
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'sem data';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatDateTime(DateTime value) {
  final date = _formatDate(value);
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$date às $hour:$minute';
}

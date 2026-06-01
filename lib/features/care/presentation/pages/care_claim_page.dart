import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/care/application/care_claim_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:file_picker/file_picker.dart';
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
      resizeToAvoidBottomInset: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = _pagePadding(constraints.maxWidth);
          return ColoredBox(
            color: context.evoluaColors.background,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: padding,
                  child: state.when(
                    loading: () => const _CareClaimLoading(),
                    error: (error, _) => _CareClaimError(error: error),
                    data: (value) => _CareDashboard(state: value),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CareDashboard extends ConsumerStatefulWidget {
  const _CareDashboard({required this.state});

  final CareClaimState state;

  @override
  ConsumerState<_CareDashboard> createState() => _CareDashboardState();
}

class _CareDashboardState extends ConsumerState<_CareDashboard>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final max = position.maxScrollExtent;
      if (position.pixels > max) {
        _scrollController.jumpTo(max);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.only(bottom: bottomInset + 20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CareClaimHeader(state: widget.state),
          const SizedBox(height: 20),
          _ClinicalSummaryPanel(report: widget.state.report),
          const SizedBox(height: 20),
          _ResponsivePair(
            primary: _MoodChartPanel(checkIns: widget.state.report.checkIns),
            secondary: _AttentionPointsPanel(report: widget.state.report),
          ),
          const SizedBox(height: 20),
          _ResponsivePair(
            primary: _InsightPanel(report: widget.state.report),
            secondary: _RitualAdherencePanel(
              rituals: widget.state.report.rituals,
            ),
          ),
          const SizedBox(height: 20),
          _PrescriptionPanel(isSending: widget.state.isSendingPrescription),
          const SizedBox(height: 20),
          _RecommendationPanel(isSending: widget.state.isSendingRecommendation),
        ],
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.primary, required this.secondary});

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: 20), secondary],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: primary),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: secondary),
          ],
        );
      },
    );
  }
}

class _CareClaimHeader extends StatelessWidget {
  const _CareClaimHeader({required this.state});

  final CareClaimState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final icon = Container(
          width: compact ? 48 : 52,
          height: compact ? 48 : 52,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.accent,
          ),
        );
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Painel clínico Evolua Care',
              softWrap: true,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.evoluaColors.textPrimary,
                fontWeight: FontWeight.w900,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Você está visualizando apenas dados autorizados pelo paciente. '
              'A chave fica no navegador e o servidor não recebe o conteúdo em texto claro.',
              softWrap: true,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.evoluaColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        );
        final expires = state.sessionExpiresAt == null
            ? null
            : _ExpirationPill(expiresAt: state.sessionExpiresAt!);

        return PrimaryPanel(
          padding: _panelPadding(constraints.maxWidth),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(height: 14),
                    title,
                    if (expires != null) ...[
                      const SizedBox(height: 14),
                      expires,
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 16),
                    Expanded(child: title),
                    if (expires != null) ...[
                      const SizedBox(width: 16),
                      expires,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _ExpirationPill extends StatelessWidget {
  const _ExpirationPill({required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.accentGold,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Expira em ${_formatDateTime(expiresAt)}',
                softWrap: true,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicalSummaryPanel extends StatelessWidget {
  const _ClinicalSummaryPanel({required this.report});

  final CareClinicalReport report;

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo clínico rápido',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 880
                  ? 4
                  : constraints.maxWidth >= 520
                  ? 2
                  : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 4.2 : 2.5,
                children: [
                  _SummaryTile(
                    icon: Icons.favorite_border_rounded,
                    label: 'Check-ins recentes',
                    value: report.checkIns.length.toString(),
                  ),
                  _SummaryTile(
                    icon: Icons.bolt_rounded,
                    label: 'Energia média',
                    value: _formatAverageEnergy(report),
                  ),
                  _SummaryTile(
                    icon: Icons.psychology_alt_outlined,
                    label: 'Estado mais recente',
                    value: _latestMood(report),
                  ),
                  _SummaryTile(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Rituais registrados',
                    value: report.completedRituals.toString(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.52),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    softWrap: true,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.evoluaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.evoluaColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChartPanel extends StatelessWidget {
  const _MoodChartPanel({required this.checkIns});

  final List<CareClinicalCheckIn> checkIns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 520
            ? 150.0
            : constraints.maxWidth < 760
            ? 200.0
            : 240.0;
        return PrimaryPanel(
          padding: _panelPadding(constraints.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Oscilação de humor',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Linha: energia registrada nos check-ins (0 a 10).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.evoluaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: height,
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
      },
    );
  }
}

class _AttentionPointsPanel extends StatelessWidget {
  const _AttentionPointsPanel({required this.report});

  final CareClinicalReport report;

  @override
  Widget build(BuildContext context) {
    final points = _attentionPoints(report);
    return PrimaryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pontos de atenção',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Sinais para apoiar a conversa clínica, sem caráter diagnóstico.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.evoluaColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (points.isEmpty)
            const Text(
              'Ainda não há dados suficientes para destacar pontos de atenção.',
            )
          else
            ...points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AttentionPoint(text: point),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttentionPoint extends StatelessWidget {
  const _AttentionPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: AppColors.accentGold,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, softWrap: true)),
      ],
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.report});

  final CareClinicalReport report;

  @override
  Widget build(BuildContext context) {
    final paragraphs = _splitInsight(report.latestInsight);
    return PrimaryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights emocionais',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Leitura resumida para orientar a conversa, não para substituir avaliação profissional.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.evoluaColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ...paragraphs.map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 7, color: AppColors.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      paragraph,
                      softWrap: true,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MetricPill(
            label: 'Check-ins no relatório',
            value: report.checkIns.length.toString(),
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
          const SizedBox(height: 8),
          Text(
            'Registros recentes de rituais concluídos pelo paciente.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.evoluaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (rituals.isEmpty)
            const Text('Nenhum ritual registrado no período do relatório.')
          else
            ...rituals.take(8).map(_RitualAdherenceTile.new),
        ],
      ),
    );
  }
}

class _RitualAdherenceTile extends StatelessWidget {
  const _RitualAdherenceTile(this.item);

  final CareClinicalRitual item;

  @override
  Widget build(BuildContext context) {
    final type = item.type == DailyRitualType.evening
        ? 'Fechamento do dia'
        : 'Ritual do dia';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDate(item.localDate)} · $type',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.evoluaColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.intention.isEmpty
                          ? 'Intenção não informada.'
                          : item.intention,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (item.microAction.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.microAction,
                        softWrap: true,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.evoluaColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 520;
        return PrimaryPanel(
          padding: _panelPadding(constraints.maxWidth),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prescrever ritual',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Envie uma rotina simples e criptografada para o app do paciente.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.evoluaColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  showSelectedIcon: false,
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
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Contexto emocional observado',
                    hintText: 'Ex.: ansiedade ao iniciar o dia',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _intentionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Intenção terapêutica',
                    hintText: 'Ex.: começar com mais presença',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _microActionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Micro-ação sugerida',
                    hintText:
                        'Ex.: respirar por dois minutos antes de mensagens',
                  ),
                  minLines: 2,
                  maxLines: 4,
                  validator: _required,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: mobile ? double.infinity : null,
                  child: FilledButton.icon(
                    onPressed: widget.isSending ? null : _submit,
                    icon: widget.isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline_rounded),
                    label: Text(
                      widget.isSending
                          ? 'Enviando...'
                          : 'Prescrever ritual personalizado',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _RecommendationPanel extends ConsumerStatefulWidget {
  const _RecommendationPanel({required this.isSending});

  final bool isSending;

  @override
  ConsumerState<_RecommendationPanel> createState() =>
      _RecommendationPanelState();
}

class _RecommendationPanelState extends ConsumerState<_RecommendationPanel> {
  final _guidanceController = TextEditingController();
  final _guidanceFocusNode = FocusNode();
  final _guidanceFieldKey = GlobalKey();
  final List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    _guidanceFocusNode.addListener(_handleGuidanceFocusChanged);
  }

  @override
  void dispose() {
    _guidanceFocusNode.removeListener(_handleGuidanceFocusChanged);
    _guidanceFocusNode.dispose();
    _guidanceController.dispose();
    super.dispose();
  }

  void _handleGuidanceFocusChanged() {
    if (_guidanceFocusNode.hasFocus) {
      _scheduleGuidanceScroll();
    }
  }

  void _scheduleGuidanceScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureGuidanceVisible();
    });
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      _ensureGuidanceVisible();
    });
  }

  void _ensureGuidanceVisible() {
    if (!mounted) return;
    final fieldContext = _guidanceFieldKey.currentContext;
    if (fieldContext == null) return;
    Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryPanel(
      padding: _panelPadding(MediaQuery.sizeOf(context).width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orientações e Recomendações Gerais',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.evoluaColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Envie orientações ou anexos. Tudo é criptografado neste navegador antes de sair daqui.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.evoluaColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Anexos aceitos: PDF, JPG, PNG ou WebP, até 10 MB por arquivo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.evoluaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _guidanceFieldKey,
            child: TextField(
              controller: _guidanceController,
              focusNode: _guidanceFocusNode,
              textCapitalization: TextCapitalization.sentences,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Orientações e Recomendações Gerais',
                hintText:
                    'Escreva recomendações, combinados ou cuidados para os próximos dias.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: widget.isSending ? null : _pickFiles,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Adicionar anexos'),
              ),
              Text(
                '${_attachments.length}/5 anexos',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.evoluaColors.textSecondary,
                ),
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._attachments.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remover anexo',
                      onPressed: widget.isSending
                          ? null
                          : () => setState(() => _attachments.remove(file)),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.isSending ? null : _submit,
              icon: widget.isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline_rounded),
              label: Text(
                widget.isSending
                    ? 'Enviando...'
                    : 'Enviar orientação segura ao paciente',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final remaining = 5 - _attachments.length;
    if (remaining <= 0) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null) return;
    final selected = result.files
        .where((file) => file.bytes != null && file.size <= 10 * 1024 * 1024)
        .take(remaining);
    setState(() => _attachments.addAll(selected));
  }

  Future<void> _submit() async {
    try {
      await ref
          .read(careClaimControllerProvider.notifier)
          .sendRecommendation(
            guidanceText: _guidanceController.text,
            attachments: List<PlatformFile>.from(_attachments),
          );
      _guidanceController.clear();
      setState(_attachments.clear);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível enviar a orientação agora.'),
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
            Expanded(child: Text(label, softWrap: true)),
            const SizedBox(width: 8),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: PrimaryPanel(
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(copy.message, textAlign: TextAlign.center),
              ],
            ),
          ),
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

EdgeInsets _pagePadding(double width) {
  if (width < 600) return const EdgeInsets.all(16);
  if (width < 920) return const EdgeInsets.all(20);
  return const EdgeInsets.all(28);
}

EdgeInsets _panelPadding(double width) {
  if (width < 600) return const EdgeInsets.all(18);
  return const EdgeInsets.all(24);
}

String _formatAverageEnergy(CareClinicalReport report) {
  final values = report.checkIns
      .map((item) => item.energyLevel)
      .whereType<int>()
      .toList();
  if (values.isEmpty) return 'sem dados';
  final average = values.reduce((a, b) => a + b) / values.length;
  return average.toStringAsFixed(1);
}

String _latestMood(CareClinicalReport report) {
  for (final item in report.checkIns) {
    final mood = item.mood.trim();
    if (mood.isNotEmpty) return mood;
  }
  return 'sem registro';
}

List<String> _attentionPoints(CareClinicalReport report) {
  final points = <String>[];
  final energies = report.checkIns
      .map((item) => item.energyLevel)
      .whereType<int>()
      .toList();
  if (energies.length >= 3) {
    final recent = energies.take(3).reduce((a, b) => a + b) / 3;
    if (recent <= 3.5) {
      points.add(
        'Energia recente baixa. Pode valer explorar sono, rotina e carga emocional.',
      );
    }
    if (energies.first + 2 <= energies.last) {
      points.add(
        'Há sinal de queda de energia entre os registros. Observe contexto e gatilhos associados.',
      );
    }
  }
  final moodCounts = <String, int>{};
  for (final item in report.checkIns) {
    final mood = item.mood.trim().toLowerCase();
    if (mood.isNotEmpty && mood != 'sem registro') {
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }
  }
  final recurring = moodCounts.entries
      .where((entry) => entry.value >= 2)
      .map((entry) => entry.key)
      .toList();
  if (recurring.isNotEmpty) {
    points.add(
      'Estados recorrentes relatados: ${recurring.take(3).join(', ')}.',
    );
  }
  if (report.checkIns.isNotEmpty && report.rituals.isEmpty) {
    points.add(
      'Há check-ins sem rituais registrados no período. Pode ser útil investigar barreiras de adesão.',
    );
  }
  return points.take(4).toList();
}

List<String> _splitInsight(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return const ['Sem insight consolidado no relatório.'];
  }
  final parts = normalized
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  return parts.isEmpty ? [normalized] : parts.take(4).toList();
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

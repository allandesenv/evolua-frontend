import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/care/application/care_share_controller.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CareSharePage extends ConsumerWidget {
  const CareSharePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(careShareControllerProvider);
    return GradientScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Voltar',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Evolua Care',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                PrimaryPanel(
                  padding: const EdgeInsets.all(22),
                  child: state.when(
                    loading: () => const _CareLoadingState(
                      text: 'Carregando acesso seguro...',
                    ),
                    error: (_, _) => _CareMessageState(
                      icon: Icons.error_outline_rounded,
                      title: 'Não foi possível carregar o Evolua Care',
                      message:
                          'Verifique sua conexão e tente novamente em instantes.',
                      actionLabel: 'Tentar novamente',
                      onAction: () =>
                          ref.invalidate(careShareControllerProvider),
                    ),
                    data: (value) => _CareShareContent(state: value),
                  ),
                ),
                const SizedBox(height: 18),
                const _CareHistoryPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CareShareContent extends ConsumerWidget {
  const _CareShareContent({required this.state});

  final CareShareState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.status == CareAccessStatus.generating) {
      return const _CareLoadingState(text: 'Preparando acesso seguro...');
    }

    if (state.status == CareAccessStatus.idle) {
      return _CareMessageState(
        icon: Icons.health_and_safety_outlined,
        title: 'Compartilhe com seu terapeuta',
        message:
            'Gere um acesso temporário para que seu terapeuta veja um relatório protegido da sua jornada emocional.',
        actionLabel: 'Gerar acesso seguro',
        onAction: () =>
            ref.read(careShareControllerProvider.notifier).generateAccess(),
      );
    }

    if (state.status == CareAccessStatus.expired) {
      return _CareMessageState(
        icon: Icons.timer_off_outlined,
        title: 'Sessão expirada',
        message:
            'O acesso temporário venceu. Gere um novo código quando estiver com seu terapeuta.',
        actionLabel: 'Gerar novo acesso',
        onAction: () =>
            ref.read(careShareControllerProvider.notifier).generateAccess(),
      );
    }

    if (state.status == CareAccessStatus.revoked) {
      return _CareMessageState(
        icon: Icons.lock_outline_rounded,
        title: 'Acesso revogado',
        message:
            'Seu terapeuta não pode mais acessar essa sessão compartilhada.',
        actionLabel: 'Gerar novo acesso',
        onAction: () =>
            ref.read(careShareControllerProvider.notifier).generateAccess(),
      );
    }

    final qrPayload = state.qrPayload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CareStatusHeader(state: state),
        const SizedBox(height: 18),
        if (qrPayload != null) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: QrImageView(
                  data: qrPayload.toString(),
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ] else ...[
          _CareInlineNotice(
            icon: Icons.qr_code_2_rounded,
            text:
                'Por segurança, gere um novo acesso para exibir o QR Code completo.',
          ),
          const SizedBox(height: 18),
        ],
        Text(
          'Código temporário',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.evoluaColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          state.numericCode ?? '------',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: context.evoluaColors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 14),
        if (state.expiresAt != null)
          Text(
            'Expira em ${_formatDateTime(state.expiresAt!)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.evoluaColors.textSecondary,
            ),
          ),
        if (state.friendlyMessage != null) ...[
          const SizedBox(height: 14),
          _CareInlineNotice(
            icon: Icons.info_outline_rounded,
            text: state.friendlyMessage!,
          ),
        ],
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: state.numericCode == null
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: state.numericCode!),
                      );
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message: 'Código copiado com segurança.',
                          icon: Icons.copy_rounded,
                        );
                      }
                    },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar código'),
            ),
            OutlinedButton.icon(
              onPressed: state.status == CareAccessStatus.revoking
                  ? null
                  : () => ref
                        .read(careShareControllerProvider.notifier)
                        .revokeAccess(),
              icon: state.status == CareAccessStatus.revoking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_off_rounded),
              label: const Text('Revogar acesso'),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month às $hour:$minute';
  }
}

class _CareStatusHeader extends StatelessWidget {
  const _CareStatusHeader({required this.state});

  final CareShareState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.status == CareAccessStatus.connected;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: (connected ? AppColors.accent : AppColors.accentGold)
                .withValues(alpha: 0.18),
          ),
          child: Icon(
            connected ? Icons.verified_user_outlined : Icons.qr_code_2_rounded,
            color: connected ? AppColors.accent : AppColors.accentGold,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connected
                    ? 'Conectado ao terapeuta'
                    : 'Acesso temporário ativo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.evoluaColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                connected
                    ? 'Seu terapeuta validou o acesso. Você pode revogar quando quiser.'
                    : 'Mostre o QR Code ou o código ao seu terapeuta somente durante a consulta.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.evoluaColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CareMessageState extends StatelessWidget {
  const _CareMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, color: AppColors.accent, size: 42),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: context.evoluaColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.evoluaColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.lock_outline_rounded),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _CareHistoryPanel extends ConsumerWidget {
  const _CareHistoryPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(careShareHistoryProvider);
    return PrimaryPanel(
      padding: const EdgeInsets.all(20),
      child: history.when(
        loading: () => const _CareLoadingState(
          text: 'Carregando histórico de conexões...',
        ),
        error: (_, _) => _CareInlineNotice(
          icon: Icons.info_outline_rounded,
          text:
              'Não foi possível carregar o histórico agora. Tente novamente mais tarde.',
        ),
        data: (items) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Histórico de conexões',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.evoluaColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Acompanhe os acessos temporários criados para atendimento.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.evoluaColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                _CareInlineNotice(
                  icon: Icons.history_rounded,
                  text: 'Nenhuma conexão anterior por enquanto.',
                )
              else
                ...items.take(6).map(_CareHistoryTile.new),
            ],
          );
        },
      ),
    );
  }
}

class _CareHistoryTile extends StatelessWidget {
  const _CareHistoryTile(this.session);

  final CareShareSession session;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (session.status) {
      CareAccessStatus.connected => 'conectada',
      CareAccessStatus.revoked => 'revogada',
      CareAccessStatus.expired => 'expirada',
      CareAccessStatus.active => 'ativa',
      _ => 'registrada',
    };
    final date =
        session.revokedAt ??
        session.claimedAt ??
        session.updatedAt ??
        session.createdAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sessão com terapeuta $statusText em ${_formatShortDate(date)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.evoluaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }
}

class _CareLoadingState extends StatelessWidget {
  const _CareLoadingState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _CareInlineNotice extends StatelessWidget {
  const _CareInlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.evoluaColors.outline.withValues(alpha: 0.48),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

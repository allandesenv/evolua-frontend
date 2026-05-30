import 'dart:async';

import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/care/application/care_recommendation_handler.dart';
import 'package:evolua_frontend/features/care/application/care_share_controller.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_access_status.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_recommendation_envelope.dart';
import 'package:evolua_frontend/features/care/domain/entities/care_share_session.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/shared/presentation/widgets/app_snackbar.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_async_button.dart';
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
    final l10n = context.l10n;
    final isSyncing = state.asData?.value.isSyncing ?? false;
    return GradientScaffold(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _syncManually(context, ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: l10n.commonBack,
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
                      IconButton(
                        tooltip: l10n.commonRefresh,
                        onPressed: isSyncing
                            ? null
                            : () => _syncManually(context, ref),
                        icon: isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PrimaryPanel(
                    padding: const EdgeInsets.all(22),
                    child: state.when(
                      loading: () =>
                          _CareLoadingState(text: l10n.careLoadingSecureAccess),
                      error: (_, _) => _CareMessageState(
                        icon: Icons.error_outline_rounded,
                        title: l10n.careLoadErrorTitle,
                        message: l10n.careLoadErrorMessage,
                        actionLabel: l10n.commonRetry,
                        onAction: () =>
                            ref.invalidate(careShareControllerProvider),
                      ),
                      data: (value) => _CareShareContent(state: value),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _CareRecommendationsPanel(),
                  const SizedBox(height: 18),
                  const _CareHistoryPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _syncManually(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(careShareControllerProvider.notifier)
        .syncPendingCare(manual: true);
    if (!context.mounted || !result.hasFailures) {
      return;
    }
    AppSnackBar.show(
      context,
      message:
          'Não foi possível sincronizar agora. Tente novamente em instantes.',
      icon: Icons.info_outline_rounded,
    );
  }
}

class _CareRecommendationsPanel extends ConsumerWidget {
  const _CareRecommendationsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recommendations = ref.watch(careRecommendationsProvider);
    return PrimaryPanel(
      padding: const EdgeInsets.all(20),
      child: recommendations.when(
        loading: () => _CareLoadingState(text: l10n.careRecommendationsLoading),
        error: (_, _) => _CareInlineNotice(
          icon: Icons.info_outline_rounded,
          text: l10n.careRecommendationsError,
        ),
        data: (items) {
          final unread = items.where((item) => !item.isRead).toList();
          final history = items.where((item) => item.isRead).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.careRecommendationsTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.evoluaColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.careRecommendationsSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.evoluaColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (unread.isEmpty)
                _CareInlineNotice(
                  icon: Icons.health_and_safety_outlined,
                  text: l10n.careRecommendationsEmpty,
                )
              else
                ...unread
                    .take(10)
                    .map(
                      (item) => _CareRecommendationTile(recommendation: item),
                    ),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Histórico de Orientações',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...history
                    .take(20)
                    .map(
                      (item) => _CareRecommendationTile(
                        recommendation: item,
                        isHistory: true,
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CareRecommendationTile extends ConsumerWidget {
  const _CareRecommendationTile({
    required this.recommendation,
    this.isHistory = false,
  });

  final CareRecommendation recommendation;
  final bool isHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.evoluaColors.surfaceStrong.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.evoluaColors.outline.withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recommendation.therapistLabel ??
                          l10n.careTherapistFallback,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!recommendation.isRead)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          'Nova',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  if (isHistory)
                    IconButton(
                      tooltip: 'Remover do histórico',
                      onPressed: () async {
                        await ref
                            .read(careRecommendationHandlerProvider)
                            .hideFromHistory(recommendation.recommendationId);
                        if (context.mounted) {
                          AppSnackBar.show(
                            context,
                            message: 'Orientação removida do histórico.',
                            icon: Icons.delete_outline_rounded,
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              ),
              if (recommendation.isRead) ...[
                const SizedBox(height: 6),
                Text(
                  'Leitura confirmada',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.evoluaColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (recommendation.guidanceText.isNotEmpty)
                Text(
                  recommendation.guidanceText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.evoluaColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              if (recommendation.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...recommendation.attachments.map(
                  (attachment) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _CareAttachmentButton(
                      recommendation: recommendation,
                      attachment: attachment,
                    ),
                  ),
                ),
              ],
              if (!recommendation.isRead) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => ref
                      .read(careRecommendationHandlerProvider)
                      .acknowledge(recommendation),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l10n.careAcknowledgeReading),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CareAttachmentButton extends ConsumerStatefulWidget {
  const _CareAttachmentButton({
    required this.recommendation,
    required this.attachment,
  });

  final CareRecommendation recommendation;
  final CareRecommendationAttachment attachment;

  @override
  ConsumerState<_CareAttachmentButton> createState() =>
      _CareAttachmentButtonState();
}

class _CareAttachmentButtonState extends ConsumerState<_CareAttachmentButton> {
  bool _isOpening = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isOpening ? null : _open,
      icon: _isOpening
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded),
      label: Text(
        widget.attachment.displayName,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _open() async {
    if (_isOpening) return;
    setState(() => _isOpening = true);
    try {
      await ref
          .read(careRecommendationHandlerProvider)
          .openAttachment(
            recommendation: widget.recommendation,
            attachment: widget.attachment,
          );
    } on CareAttachmentMissingSecretException {
      if (mounted) {
        AppSnackBar.show(
          context,
          message:
              'A chave de segurança desta sessão não está mais disponível. Não é possível abrir o anexo.',
          icon: Icons.info_outline_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message:
              'Não foi possível abrir este anexo agora. Tente novamente em instantes.',
          icon: Icons.info_outline_rounded,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }
}

class _CareShareContent extends ConsumerWidget {
  const _CareShareContent({required this.state});

  final CareShareState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (state.status == CareAccessStatus.generating) {
      return _CareLoadingState(text: l10n.carePreparingAccess);
    }

    if (state.status == CareAccessStatus.idle) {
      return _CareMessageState(
        icon: Icons.health_and_safety_outlined,
        title: l10n.careShareTitle,
        message: l10n.careShareMessage,
        actionLabel: l10n.careGenerateSecureAccess,
        onAction: () =>
            ref.read(careShareControllerProvider.notifier).generateAccess(),
      );
    }

    if (state.status == CareAccessStatus.expired) {
      return _CareMessageState(
        icon: Icons.timer_off_outlined,
        title: l10n.careExpiredTitle,
        message: l10n.careExpiredMessage,
        actionLabel: l10n.careGenerateNewAccess,
        onAction: () =>
            ref.read(careShareControllerProvider.notifier).generateAccess(),
      );
    }

    if (state.status == CareAccessStatus.revoked) {
      return _CareMessageState(
        icon: Icons.lock_outline_rounded,
        title: l10n.careRevokedTitle,
        message: l10n.careRevokedMessage,
        actionLabel: l10n.careGenerateNewAccess,
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
            text: l10n.careQrMissing,
          ),
          const SizedBox(height: 18),
        ],
        Text(
          l10n.careTemporaryCode,
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
            l10n.careExpiresAt(_formatDateTime(state.expiresAt!)),
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
            EvoluaAsyncButton.filled(
              onPressed: state.numericCode == null
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: state.numericCode!),
                      );
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message: l10n.careCodeCopied,
                          icon: Icons.copy_rounded,
                        );
                      }
                    },
              icon: Icons.copy_rounded,
              label: l10n.careCopyCode,
            ),
            if (qrPayload != null)
              EvoluaAsyncButton.outlined(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: qrPayload.toString()),
                  );
                  if (context.mounted) {
                    AppSnackBar.show(
                      context,
                      message: l10n.careFullLinkCopied,
                      icon: Icons.link_rounded,
                    );
                  }
                },
                icon: Icons.link_rounded,
                label: l10n.careCopyFullLink,
              ),
            EvoluaAsyncButton.outlined(
              onPressed: state.status == CareAccessStatus.revoking
                  ? null
                  : () => ref
                        .read(careShareControllerProvider.notifier)
                        .revokeAccess(),
              isBusy: state.status == CareAccessStatus.revoking,
              icon: Icons.link_off_rounded,
              label: l10n.careRevokeAccess,
              loadingLabel: l10n.commonLoading,
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
    final l10n = context.l10n;
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
                connected ? l10n.careConnectedTitle : l10n.careActiveTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.evoluaColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                connected ? l10n.careConnectedMessage : l10n.careActiveMessage,
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
  final FutureOr<void> Function() onAction;

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
        EvoluaAsyncButton.filled(
          onPressed: onAction,
          icon: Icons.lock_outline_rounded,
          label: actionLabel,
          loadingLabel: context.l10n.commonLoading,
          expand: true,
        ),
      ],
    );
  }
}

class _CareHistoryPanel extends ConsumerWidget {
  const _CareHistoryPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(careShareHistoryProvider);
    return PrimaryPanel(
      padding: const EdgeInsets.all(20),
      child: history.when(
        loading: () => _CareLoadingState(text: l10n.careHistoryLoading),
        error: (_, _) => _CareInlineNotice(
          icon: Icons.info_outline_rounded,
          text: l10n.careHistoryError,
        ),
        data: (items) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.careHistoryTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.evoluaColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.careHistorySubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.evoluaColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                _CareInlineNotice(
                  icon: Icons.history_rounded,
                  text: l10n.careHistoryEmpty,
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
    final l10n = context.l10n;
    final statusText = switch (session.status) {
      CareAccessStatus.connected => l10n.careStatusConnected,
      CareAccessStatus.revoked => l10n.careStatusRevoked,
      CareAccessStatus.expired => l10n.careStatusExpired,
      CareAccessStatus.active => l10n.careStatusActive,
      _ => l10n.careStatusRegistered,
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
          const Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.careHistoryTile(statusText, _formatShortDate(date)),
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

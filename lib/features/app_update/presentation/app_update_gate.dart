import 'dart:async';

import 'package:evolua_frontend/features/app_update/application/app_update_route_state.dart';
import 'package:evolua_frontend/features/app_update/application/app_update_service.dart';
import 'package:evolua_frontend/features/app_update/application/app_version_status_controller.dart';
import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:evolua_frontend/shared/presentation/widgets/evolua_logo.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appUpdateGateEnabledProvider = Provider<bool>((ref) {
  final isWidgetTest = WidgetsBinding.instance.runtimeType.toString().contains(
    'TestWidgetsFlutterBinding',
  );
  return !isWidgetTest;
});

class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  String? _dismissedRecommendedKey;
  bool _recommendedUpdating = false;

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(appUpdateGateEnabledProvider)) {
      return widget.child;
    }
    final state = ref.watch(appVersionStatusProvider).asData?.value;
    final status = state?.status;
    final routePath = ref.watch(appUpdateCurrentRouteProvider);
    final sensitive =
        ref.watch(appUpdateSensitiveFlowProvider) ||
        _isSensitive(routePath) ||
        _hasCareClaimHash() ||
        _hasModalOpen(context);

    if (state != null &&
        !state.disabled &&
        status != null &&
        status.updateRequired &&
        !sensitive) {
      return RequiredUpdateScreen(status: status);
    }

    if (state != null &&
        !state.disabled &&
        status != null &&
        status.updateRecommended &&
        routePath == '/home' &&
        !sensitive) {
      final key =
          '${state.platform}-${state.versionCode}-${state.status.latestVersionCode}';
      if (_dismissedRecommendedKey != key) {
        return Stack(
          children: [
            widget.child,
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: RecommendedUpdateCard(
                  status: status,
                  updating: _recommendedUpdating,
                  onDismiss: () {
                    setState(() => _dismissedRecommendedKey = key);
                  },
                  onUpdate: () => _startRecommendedUpdate(status),
                ),
              ),
            ),
          ],
        );
      }
    }

    return widget.child;
  }

  bool _hasModalOpen(BuildContext context) {
    try {
      return Navigator.of(context).canPop();
    } catch (_) {
      return false;
    }
  }

  bool _isSensitive(String routePath) {
    return routePath == '/check-in' ||
        routePath == '/daily-ritual' ||
        routePath == '/care/share' ||
        routePath == '/care/claim';
  }

  bool _hasCareClaimHash() {
    final fragment = Uri.base.fragment;
    return fragment == '/care/claim' || fragment.startsWith('/care/claim?');
  }

  Future<void> _startRecommendedUpdate(AppVersionStatus status) async {
    setState(() => _recommendedUpdating = true);
    final service = ref.read(appUpdateServiceProvider);
    final flexibleStarted = await service.startFlexibleUpdate();
    if (!flexibleStarted) {
      await service.openStore(status.storeUrl);
    }
    if (mounted) {
      setState(() => _recommendedUpdating = false);
    }
  }
}

class RecommendedUpdateCard extends StatelessWidget {
  const RecommendedUpdateCard({
    required this.status,
    required this.updating,
    required this.onDismiss,
    required this.onUpdate,
    super.key,
  });

  final AppVersionStatus status;
  final bool updating;
  final VoidCallback onDismiss;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.appUpdateRecommendedTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status.message.isEmpty
                  ? context.l10n.appUpdateRecommendedFallbackMessage
                  : status.message,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: updating ? null : onDismiss,
                  child: Text(context.l10n.appUpdateDismiss),
                ),
                FilledButton(
                  onPressed: updating ? null : onUpdate,
                  child: updating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.appUpdateAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RequiredUpdateScreen extends ConsumerStatefulWidget {
  const RequiredUpdateScreen({required this.status, super.key});

  final AppVersionStatus status;

  @override
  ConsumerState<RequiredUpdateScreen> createState() =>
      _RequiredUpdateScreenState();
}

class _RequiredUpdateScreenState extends ConsumerState<RequiredUpdateScreen> {
  bool _attemptedImmediate = false;
  bool _openingStore = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_attemptedImmediate) {
      _attemptedImmediate = true;
      unawaited(ref.read(appUpdateServiceProvider).performImmediateUpdate());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: EvoluaLogo(variant: EvoluaLogoVariant.sidebar),
                ),
                const SizedBox(height: 28),
                Text(
                  context.l10n.appUpdateRequiredTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.status.message.isEmpty
                      ? context.l10n.appUpdateRequiredFallbackMessage
                      : widget.status.message,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _openingStore ? null : _openStore,
                  child: _openingStore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.appUpdateGooglePlayAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    setState(() => _openingStore = true);
    await ref.read(appUpdateServiceProvider).openStore(widget.status.storeUrl);
    if (mounted) {
      setState(() => _openingStore = false);
    }
  }
}

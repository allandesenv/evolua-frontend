import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const mentorPremiumPassRewardType = 'MENTOR_PREMIUM_PASS';

final mentorPremiumPassPollingConfigProvider =
    Provider<MentorPremiumPassPollingConfig>((ref) {
      return const MentorPremiumPassPollingConfig(
        timeout: Duration(seconds: 12),
        interval: Duration(seconds: 1),
      );
    });

final mentorPremiumPassRewardServiceProvider =
    Provider<MentorPremiumPassRewardService>((ref) {
      return MentorPremiumPassRewardService(ref);
    });

class MentorPremiumPassPollingConfig {
  const MentorPremiumPassPollingConfig({
    required this.timeout,
    required this.interval,
  });

  final Duration timeout;
  final Duration interval;
}

enum MentorPremiumPassRewardStatus {
  unavailable,
  confirmed,
  confirmationPending,
}

class MentorPremiumPassRewardResult {
  const MentorPremiumPassRewardResult(this.status);

  final MentorPremiumPassRewardStatus status;

  bool get confirmed => status == MentorPremiumPassRewardStatus.confirmed;
}

class MentorPremiumPassRewardService {
  const MentorPremiumPassRewardService(this._ref);

  final Ref _ref;

  Future<MentorPremiumPassRewardResult> watchAdAndConfirm({
    int? trailId,
    VoidCallback? onAwaitingConfirmation,
  }) async {
    final rewarded = await _ref
        .read(rewardedAdServiceProvider)
        .showRewardedAd(rewardType: mentorPremiumPassRewardType);

    if (!rewarded) {
      return const MentorPremiumPassRewardResult(
        MentorPremiumPassRewardStatus.unavailable,
      );
    }

    onAwaitingConfirmation?.call();

    final config = _ref.read(mentorPremiumPassPollingConfigProvider);
    final deadline = DateTime.now().add(config.timeout);

    while (true) {
      await _ref.read(subscriptionControllerProvider.notifier).refresh();
      final passActive =
          _ref
              .read(subscriptionControllerProvider)
              .asData
              ?.value
              .current
              ?.mentorPremiumPassActive ??
          false;

      if (passActive) {
        await _ref.read(trailControllerProvider.notifier).refresh();
        _ref.invalidate(currentJourneyTrailProvider);
        if (trailId != null) {
          _ref.invalidate(trailJourneyProvider(trailId));
        }
        return const MentorPremiumPassRewardResult(
          MentorPremiumPassRewardStatus.confirmed,
        );
      }

      if (!DateTime.now().isBefore(deadline)) {
        return const MentorPremiumPassRewardResult(
          MentorPremiumPassRewardStatus.confirmationPending,
        );
      }

      await Future<void>.delayed(config.interval);
    }
  }
}

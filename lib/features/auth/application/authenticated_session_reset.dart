import 'dart:async';

import 'package:evolua_frontend/app/startup/app_startup_controller.dart';
import 'package:evolua_frontend/features/ads/application/monetization_access_controller.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/care/application/care_recommendation_handler.dart';
import 'package:evolua_frontend/features/care/application/care_share_controller.dart';
import 'package:evolua_frontend/features/chat/application/chat_message_controller.dart';
import 'package:evolua_frontend/features/content/application/journey_chat_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/application/consciousness_timeline_controller.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_ready_summary_controller.dart';
import 'package:evolua_frontend/features/notification/application/local_check_in_reminder_controller.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/user/application/accessibility_preferences_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/application/settings_privacy_preferences_controller.dart';
import 'package:evolua_frontend/features/user/application/support_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authenticatedSessionResetObserverProvider = Provider<void>((ref) {
  var lastUserId = ref.read(authControllerProvider).asData?.value?.userId;
  var resetScheduledForLoadingSession = false;
  ref.listen(authControllerProvider, (previous, next) {
    if (next.isLoading) {
      if (lastUserId != null && !resetScheduledForLoadingSession) {
        scheduleAuthenticatedSessionReset(ref);
        resetScheduledForLoadingSession = true;
      }
      return;
    }

    if (!next.hasValue) {
      return;
    }

    resetScheduledForLoadingSession = false;
    final nextUserId = next.value?.userId;
    if (lastUserId != nextUserId &&
        (lastUserId != null || nextUserId != null)) {
      scheduleAuthenticatedSessionReset(ref);
    }
    lastUserId = nextUserId;
  });
});

Future<void> resetAuthenticatedSessionState(Ref ref) async {
  ref.read(authSessionGenerationProvider.notifier).bump();
  ref.read(appStartupControllerProvider).reset();
  _invalidateAuthenticatedProviders(ref);

  await SocialPostController.clearOfflineCache(ref);
}

void scheduleAuthenticatedSessionReset(Ref ref) {
  unawaited(resetAuthenticatedSessionState(ref));
}

void _invalidateAuthenticatedProviders(Ref ref) {
  ref
    ..invalidate(profileControllerProvider)
    ..invalidate(checkInControllerProvider)
    ..invalidate(trailControllerProvider)
    ..invalidate(currentJourneyTrailProvider)
    ..invalidate(inProgressTrailJourneysProvider)
    ..invalidate(trailJourneyProvider)
    ..invalidate(trailStepResponseProvider)
    ..invalidate(trailStepResponsesProvider)
    ..invalidate(journeyChatControllerProvider)
    ..invalidate(dailyRitualControllerProvider)
    ..invalidate(consciousnessTimelineProvider)
    ..invalidate(evolutionMirrorSummaryProvider)
    ..invalidate(futureMessageControllerProvider)
    ..invalidate(futureMessageReadySummaryControllerProvider)
    ..invalidate(socialPostControllerProvider)
    ..invalidate(communityControllerProvider)
    ..invalidate(currentSubscriptionProvider)
    ..invalidate(subscriptionControllerProvider)
    ..invalidate(monetizationAccessControllerProvider)
    ..invalidate(notificationUnreadCountControllerProvider)
    ..invalidate(notificationInboxControllerProvider)
    ..invalidate(dailyCheckInReminderControllerProvider)
    ..invalidate(careShareControllerProvider)
    ..invalidate(careShareHistoryProvider)
    ..invalidate(careRecommendationsProvider)
    ..invalidate(chatMessageControllerProvider)
    ..invalidate(settingsPrivacyPreferencesControllerProvider)
    ..invalidate(accessibilityPreferencesControllerProvider)
    ..invalidate(supportConfigProvider)
    ..invalidate(supportStatusProvider);
}

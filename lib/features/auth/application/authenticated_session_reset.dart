import 'dart:async';

import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/chat/application/chat_message_controller.dart';
import 'package:evolua_frontend/features/content/application/journey_chat_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
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
  ref.invalidate(profileControllerProvider);
  ref.invalidate(checkInControllerProvider);
  ref.invalidate(trailControllerProvider);
  ref.invalidate(currentJourneyTrailProvider);
  ref.invalidate(trailJourneyProvider);
  ref.invalidate(journeyChatControllerProvider);
  ref.invalidate(dailyRitualControllerProvider);
  ref.invalidate(futureMessageControllerProvider);
  ref.invalidate(socialPostControllerProvider);
  ref.invalidate(communityControllerProvider);
  ref.invalidate(subscriptionControllerProvider);
  ref.invalidate(notificationInboxControllerProvider);
  ref.invalidate(chatMessageControllerProvider);
  ref.invalidate(supportConfigProvider);
  ref.invalidate(supportStatusProvider);

  await SocialPostController.clearOfflineCache(ref);
}

void scheduleAuthenticatedSessionReset(Ref ref) {
  unawaited(resetAuthenticatedSessionState(ref));
}

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'EVOLUA_API_BASE_URL',
    //defaultValue: 'https://evolua-api-hml-production.up.railway.app',
    defaultValue: 'https://evolua-api-production.up.railway.app',
    //defaultValue: 'http://192.168.0.47:8080',
  );

  static const authBaseUrl = String.fromEnvironment(
    'EVOLUA_AUTH_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const userBaseUrl = String.fromEnvironment(
    'EVOLUA_USER_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const contentBaseUrl = String.fromEnvironment(
    'EVOLUA_CONTENT_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const emotionalBaseUrl = String.fromEnvironment(
    'EVOLUA_EMOTIONAL_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const aiBaseUrl = String.fromEnvironment(
    'EVOLUA_AI_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const socialBaseUrl = String.fromEnvironment(
    'EVOLUA_SOCIAL_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const chatBaseUrl = String.fromEnvironment(
    'EVOLUA_CHAT_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const subscriptionBaseUrl = String.fromEnvironment(
    'EVOLUA_SUBSCRIPTION_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const notificationBaseUrl = String.fromEnvironment(
    'EVOLUA_NOTIFICATION_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const appDeepLinkBaseUrl = String.fromEnvironment(
    'EVOLUA_APP_DEEP_LINK_BASE_URL',
    defaultValue: 'evolua://app',
  );

  static const versionStatusBaseUrl = String.fromEnvironment(
    'EVOLUA_VERSION_STATUS_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const evoluaPlayStoreUrl = String.fromEnvironment(
    'EVOLUA_PLAY_STORE_URL',
    defaultValue:
        'https://play.google.com/store/apps/details?id=br.com.zenithit.evolua',
  );

  static const appUpdateCheckEnabled = bool.fromEnvironment(
    'EVOLUA_APP_UPDATE_CHECK_ENABLED',
    defaultValue: true,
  );

  static const privacyPolicyUrl = String.fromEnvironment(
    'EVOLUA_PRIVACY_POLICY_URL',
    defaultValue:
        'https://allandesenv.github.io/evolua-legal/politica-de-privacidade.html',
  );

  static const termsOfUseUrl = String.fromEnvironment(
    'EVOLUA_TERMS_OF_USE_URL',
    defaultValue:
        'https://allandesenv.github.io/evolua-legal/termos-de-uso.html',
  );

  static const carePortalBaseUrl = String.fromEnvironment(
    'EVOLUA_CARE_PORTAL_BASE_URL',
    defaultValue: 'https://allandesenv.github.io/evolua-frontend',
  );

  static const careBaseUrl = String.fromEnvironment(
    'EVOLUA_CARE_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static const adMobAndroidRewardedAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_ANDROID_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-1136517314419681/4183412880',
  );

  static const adMobAndroidRewardedAiExtraAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_ANDROID_REWARDED_AI_EXTRA_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-1136517314419681/4183412880',
  );

  static const adMobAndroidRewardedExtraCheckInAdUnitId =
      String.fromEnvironment(
        'EVOLUA_ADMOB_ANDROID_REWARDED_EXTRA_CHECKIN_AD_UNIT_ID',
        defaultValue: adMobAndroidRewardedAiExtraAdUnitId,
      );

  static const adMobAndroidRewardedPremiumPassAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_ANDROID_REWARDED_PREMIUM_PASS_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-1136517314419681/7734426496',
  );

  static const adMobAndroidRewardedTestAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static const adMobAndroidInterstitialFreeAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_ANDROID_INTERSTITIAL_FREE_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-1136517314419681/5451133226',
  );

  static const adMobAndroidInterstitialTestAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static const adMobIosRewardedAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_IOS_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  static const adMobIosRewardedAiExtraAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_IOS_REWARDED_AI_EXTRA_AD_UNIT_ID',
    defaultValue: adMobIosRewardedAdUnitId,
  );

  static const adMobIosRewardedExtraCheckInAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_IOS_REWARDED_EXTRA_CHECKIN_AD_UNIT_ID',
    defaultValue: adMobIosRewardedAiExtraAdUnitId,
  );

  static const adMobIosRewardedPremiumPassAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_IOS_REWARDED_PREMIUM_PASS_AD_UNIT_ID',
    defaultValue: adMobIosRewardedAdUnitId,
  );

  static const adMobIosRewardedTestAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  static const adMobIosInterstitialFreeAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_IOS_INTERSTITIAL_FREE_AD_UNIT_ID',
    defaultValue: '',
  );

  static const adMobIosInterstitialTestAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  static bool get adMobUseTestAds {
    if (const bool.hasEnvironment('EVOLUA_ADMOB_USE_TEST_ADS')) {
      return const bool.fromEnvironment('EVOLUA_ADMOB_USE_TEST_ADS');
    }
    return !kReleaseMode;
  }

  static String get chatSocketUrl {
    return chatBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }

  static String get careSocketUrl {
    return careBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }
}

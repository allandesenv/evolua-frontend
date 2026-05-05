class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'EVOLUA_API_BASE_URL',
    defaultValue: 'http://192.168.0.42:8080',
  );

  static const authBaseUrl = String.fromEnvironment(
    'EVOLUA_AUTH_BASE_URL',
    defaultValue: 'http://192.168.0.42:8081',
  );

  static const userBaseUrl = String.fromEnvironment(
    'EVOLUA_USER_BASE_URL',
    defaultValue: 'http://192.168.0.42:8082',
  );

  static const contentBaseUrl = String.fromEnvironment(
    'EVOLUA_CONTENT_BASE_URL',
    defaultValue: 'http://192.168.0.42:8083',
  );

  static const emotionalBaseUrl = String.fromEnvironment(
    'EVOLUA_EMOTIONAL_BASE_URL',
    defaultValue: 'http://192.168.0.42:8084',
  );

  static const aiBaseUrl = String.fromEnvironment(
    'EVOLUA_AI_BASE_URL',
    defaultValue: 'http://192.168.0.42:8089',
  );

  static const socialBaseUrl = String.fromEnvironment(
    'EVOLUA_SOCIAL_BASE_URL',
    defaultValue: 'http://192.168.0.42:8085',
  );

  static const chatBaseUrl = String.fromEnvironment(
    'EVOLUA_CHAT_BASE_URL',
    defaultValue: 'http://192.168.0.42:8086',
  );

  static const subscriptionBaseUrl = String.fromEnvironment(
    'EVOLUA_SUBSCRIPTION_BASE_URL',
    defaultValue: 'http://192.168.0.42:8087',
  );

  static const notificationBaseUrl = String.fromEnvironment(
    'EVOLUA_NOTIFICATION_BASE_URL',
    defaultValue: 'http://192.168.0.42:8088',
  );

  static const adMobAndroidRewardedAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_ANDROID_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );

  static const adMobIosRewardedAdUnitId = String.fromEnvironment(
    'EVOLUA_ADMOB_IOS_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  static String get chatSocketUrl {
    return chatBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }
}

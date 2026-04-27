class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'EVOLUA_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const authBaseUrl = String.fromEnvironment(
    'EVOLUA_AUTH_BASE_URL',
    defaultValue: 'http://localhost:8081',
  );

  static const userBaseUrl = String.fromEnvironment(
    'EVOLUA_USER_BASE_URL',
    defaultValue: 'http://localhost:8082',
  );

  static const contentBaseUrl = String.fromEnvironment(
    'EVOLUA_CONTENT_BASE_URL',
    defaultValue: 'http://localhost:8083',
  );

  static const emotionalBaseUrl = String.fromEnvironment(
    'EVOLUA_EMOTIONAL_BASE_URL',
    defaultValue: 'http://localhost:8084',
  );

  static const aiBaseUrl = String.fromEnvironment(
    'EVOLUA_AI_BASE_URL',
    defaultValue: 'http://localhost:8089',
  );

  static const socialBaseUrl = String.fromEnvironment(
    'EVOLUA_SOCIAL_BASE_URL',
    defaultValue: 'http://localhost:8085',
  );

  static const chatBaseUrl = String.fromEnvironment(
    'EVOLUA_CHAT_BASE_URL',
    defaultValue: 'http://localhost:8086',
  );

  static const subscriptionBaseUrl = String.fromEnvironment(
    'EVOLUA_SUBSCRIPTION_BASE_URL',
    defaultValue: 'http://localhost:8087',
  );

  static const notificationBaseUrl = String.fromEnvironment(
    'EVOLUA_NOTIFICATION_BASE_URL',
    defaultValue: 'http://localhost:8088',
  );

  static String get chatSocketUrl {
    return chatBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }
}

enum Environment {
  local,
  develop,
  beta,
  production;

  static Environment get current {
    const envString = String.fromEnvironment('ENV', defaultValue: 'local');
    return Environment.values.firstWhere(
      (e) => e.name == envString,
      orElse: () => Environment.local,
    );
  }
}

class ApiConfig {
  // Base URLs per environment
  static String get baseUrl {
    switch (Environment.current) {
      case Environment.local:
        return 'http://localhost:8940';
      case Environment.develop:
        return 'https://api-dev.muse.app';
      case Environment.beta:
        return 'https://api-beta.muse.app';
      case Environment.production:
        return 'https://api.muse.app';
    }
  }

  // Timeouts
  static Duration get connectTimeout => Environment.current == Environment.local
      ? const Duration(seconds: 60)
      : const Duration(seconds: 30);

  static Duration get receiveTimeout => Environment.current == Environment.local
      ? const Duration(seconds: 60)
      : const Duration(seconds: 30);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  // Rate limiting
  static const Duration rateLimitBackoff = Duration(seconds: 5);

  // Logging
  static bool get enableDetailedLogging =>
      Environment.current == Environment.local ||
      Environment.current == Environment.develop;
}

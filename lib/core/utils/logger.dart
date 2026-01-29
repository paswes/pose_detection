import 'dart:developer' as developer;

const loggingEnabled = false;

/// Centralized logging utility for the application
class Logger {
  /// Log a message with a tag and optional level
  static void log(
    String tag,
    String message, {
    LogLevel level = LogLevel.info,
  }) {
    if (!loggingEnabled) return;
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final levelPrefix = _getLevelPrefix(level);
    developer.log('[$timestamp] [$levelPrefix] [$tag] $message');
  }

  /// Log debug information (verbose)
  static void debug(String tag, String message) {
    if (!loggingEnabled) return;
    log(tag, message, level: LogLevel.debug);
  }

  /// Log general information
  static void info(String tag, String message) {
    if (!loggingEnabled) return;
    log(tag, message, level: LogLevel.info);
  }

  /// Log warning messages
  static void warning(String tag, String message) {
    if (!loggingEnabled) return;
    log(tag, message, level: LogLevel.warning);
  }

  /// Log error messages
  static void error(String tag, String message) {
    if (!loggingEnabled) return;
    log(tag, message, level: LogLevel.error);
  }

  static String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

/// Log levels for filtering and categorization
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

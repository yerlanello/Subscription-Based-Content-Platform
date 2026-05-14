import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    const override = String.fromEnvironment('BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080/api';
    return 'http://localhost:8080/api';
  }

  // Returns an absolute URL suitable for the current platform.
  // - Relative paths are prefixed with the server origin.
  // - Absolute URLs that contain "localhost" are rewritten to 10.0.2.2 on
  //   Android so the emulator can reach the host machine (Minio, etc.).
  static String absoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      if (!kIsWeb && Platform.isAndroid) {
        return url.replaceFirst('localhost', '10.0.2.2');
      }
      return url;
    }
    // Relative path → prepend server origin.
    final uri = Uri.parse(baseUrl);
    final port = uri.hasPort &&
            !((uri.scheme == 'https' && uri.port == 443) ||
                (uri.scheme == 'http' && uri.port == 80))
        ? ':${uri.port}'
        : '';
    return '${uri.scheme}://${uri.host}$port$url';
  }
}

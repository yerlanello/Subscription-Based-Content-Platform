import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    const override = String.fromEnvironment('BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080/api';
    return 'http://localhost:8080/api';
  }

  // Returns an absolute URL. If [url] is already absolute, returns it unchanged.
  // Relative URLs (starting with /) are prefixed with the server origin derived
  // from [baseUrl] so that media served by the same host resolves correctly.
  static String absoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final uri = Uri.parse(baseUrl);
    final port = uri.hasPort &&
            !((uri.scheme == 'https' && uri.port == 443) ||
                (uri.scheme == 'http' && uri.port == 80))
        ? ':${uri.port}'
        : '';
    return '${uri.scheme}://${uri.host}$port$url';
  }
}

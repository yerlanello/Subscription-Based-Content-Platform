import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    const override = String.fromEnvironment('BASE_URL');
    if (override.isNotEmpty) {
      assert(
        override.startsWith('https://'),
        'BASE_URL must use HTTPS in production. Got: $override',
      );
      return override;
    }
    // Dev-only fallbacks — never used in production builds (BASE_URL is always set there).
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080/api';
    return 'http://localhost:8080/api';
  }

  // Returns an absolute URL suitable for the current platform.
  // - Relative paths are prefixed with the server origin.
  // - Absolute URLs whose host is localhost/127.0.0.1 are rewritten to the
  //   host from `baseUrl` so physical devices (which can't reach the host
  //   machine via "localhost") use the same reachable host as the API. The
  //   original port is preserved so Minio (9000) and the API (8080) stay
  //   distinct.
  static String absoluteUrl(String url) {
    final baseUri = Uri.parse(baseUrl);
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri == null) return url;
      final isLoopback = uri.host == 'localhost' || uri.host == '127.0.0.1';
      if (isLoopback && baseUri.host != uri.host) {
        return uri.replace(host: baseUri.host).toString();
      }
      return url;
    }
    // Relative path → prepend server origin.
    final port = baseUri.hasPort &&
            !((baseUri.scheme == 'https' && baseUri.port == 443) ||
                (baseUri.scheme == 'http' && baseUri.port == 80))
        ? ':${baseUri.port}'
        : '';
    return '${baseUri.scheme}://${baseUri.host}$port$url';
  }
}

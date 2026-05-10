class AppConfig {
  // Production default is HTTPS. For local dev, override at build time:
  //   flutter run --dart-define=BASE_URL=http://localhost:8080/api
  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://api.xabarla.com/api',
  );

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

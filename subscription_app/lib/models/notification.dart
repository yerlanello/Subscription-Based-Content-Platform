class AppNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final String? link;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.link,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'info',
        // Backend sends `title` (+ optional `body`/`link`), not `message`.
        title: json['title'] as String? ?? '',
        body: json['body'] as String?,
        link: json['link'] as String?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: json['created_at'] as String? ?? '',
      );
}

import '../models/notification.dart';
import 'api_client.dart';

class NotificationsService {
  static Future<List<AppNotification>> list() async {
    final res = await ApiClient.get('/notifications');
    final payload = res['data'] as Map<String, dynamic>? ?? {};
    final data = payload['notifications'] as List<dynamic>? ?? [];
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> markRead(String id) async {
    await ApiClient.post('/notifications/$id/read');
  }

  static Future<void> markAllRead() async {
    await ApiClient.post('/notifications/read-all');
  }

  static Future<void> delete(String id) async {
    await ApiClient.delete('/notifications/$id');
  }

  static Future<int> unreadCount() async {
    final all = await list();
    return all.where((n) => !n.isRead).length;
  }
}

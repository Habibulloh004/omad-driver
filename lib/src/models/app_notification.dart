enum NotificationCategory { orderUpdate, promotion, system }

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationCategory category;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      timestamp: timestamp,
      category: category,
      isRead: isRead ?? this.isRead,
    );
  }
}

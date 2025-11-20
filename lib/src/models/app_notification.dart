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

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? json['notification_type'] ?? '')
        .toString()
        .toLowerCase();
    final category = switch (rawType) {
      'order' ||
      'order_update' ||
      'order-update' ||
      'new_order' ||
      'order_assigned' => NotificationCategory.orderUpdate,
      'promotion' || 'promo' => NotificationCategory.promotion,
      _ => NotificationCategory.system,
    };

    final createdAtRaw = json['created_at']?.toString();
    DateTime timestamp;
    if (createdAtRaw == null || createdAtRaw.isEmpty) {
      timestamp = DateTime.now();
    } else {
      timestamp = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    }

    return AppNotification(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      timestamp: timestamp,
      category: category,
      isRead: json['is_read'] == true,
    );
  }

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

  AppNotification markRead() => copyWith(isRead: true);
}

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/order.dart';
import '../models/user.dart';

class MockData {
  const MockData._();

  static const Map<String, List<String>> regions = {
    'Toshkent': ['Mirzo Ulug‘bek', 'Yunusobod', 'Yakkasaroy', 'Chilonzor'],
    'Samarqand': ['Samarqand shahri', 'Urgut', 'Kattaqo‘rg‘on'],
    'Farg‘ona': ['Farg‘ona shahri', 'Qo‘qon', 'Marg‘ilon'],
    'Buxoro': ['Buxoro shahri', 'G‘ijduvon'],
  };

  static AppUser defaultUser() => AppUser(
    id: 'user-001',
    fullName: 'Abror Xudoyberdiyev',
    phoneNumber: '+998 90 123 45 67',
    avatarUrl:
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=200&q=80',
    rating: 4.8,
  );

  static List<AppOrder> mockOrders() {
    final now = TimeOfDay.now();
    final later = TimeOfDay(
      hour: (now.hour + 1) % 24,
      minute: (now.minute + 30) % 60,
    );

    return [
      AppOrder(
        id: 'ORD-2024-001',
        type: OrderType.taxi,
        fromRegion: 'Toshkent',
        fromDistrict: 'Yunusobod',
        toRegion: 'Toshkent',
        toDistrict: 'Chilonzor',
        passengers: 1,
        date: DateTime.now(),
        startTime: now,
        endTime: later,
        price: 35000,
        status: OrderStatus.active,
        note: 'Ofisga yetib borgach telefon qiling.',
        driverName: 'Jahongir Karimov',
        driverPhone: '+998 97 556 78 90',
        vehicle: 'Chevrolet Malibu',
        vehiclePlate: '01 A777 AA',
      ),
      AppOrder(
        id: 'ORD-2024-002',
        type: OrderType.delivery,
        fromRegion: 'Samarqand',
        fromDistrict: 'Urgut',
        toRegion: 'Toshkent',
        toDistrict: 'Mirzo Ulug‘bek',
        passengers: 1,
        date: DateTime.now().subtract(const Duration(days: 1)),
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 18, minute: 30),
        price: 78000,
        status: OrderStatus.completed,
        note: 'Hujjatlar, ehtiyotkorlik bilan.',
        driverName: 'Dilshod Mirzayev',
        driverPhone: '+998 93 456 12 34',
        vehicle: 'Damas',
        vehiclePlate: '30 B456 BB',
      ),
      AppOrder(
        id: 'ORD-2024-003',
        type: OrderType.taxi,
        fromRegion: 'Farg‘ona',
        fromDistrict: 'Marg‘ilon',
        toRegion: 'Farg‘ona',
        toDistrict: 'Farg‘ona shahri',
        passengers: 2,
        date: DateTime.now().subtract(const Duration(days: 3)),
        startTime: const TimeOfDay(hour: 9, minute: 20),
        endTime: const TimeOfDay(hour: 10, minute: 10),
        price: 45000,
        status: OrderStatus.cancelled,
        note: 'Safar bekor qilindi.',
      ),
    ];
  }

  static List<AppNotification> notifications() {
    return [
      AppNotification(
        id: 'NOTIF-001',
        title: 'Buyurtma qabul qilindi',
        message:
            'Sizning Toshkentdagi taksi buyurtmangiz haydovchiga yuborildi.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
        category: NotificationCategory.orderUpdate,
      ),
      AppNotification(
        id: 'NOTIF-002',
        title: 'Promo chegirma',
        message: 'Bugun barcha yetkazib berish xizmatlariga 15% chegirma!',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        category: NotificationCategory.promotion,
      ),
      AppNotification(
        id: 'NOTIF-003',
        title: 'Profil ma\'lumotlari yangilandi',
        message: 'Ismingiz va telefon raqamingiz muvaffaqiyatli saqlandi.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        category: NotificationCategory.system,
        isRead: true,
      ),
    ];
  }
}

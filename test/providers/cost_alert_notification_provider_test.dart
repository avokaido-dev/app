import 'package:flutter_test/flutter_test.dart';
import 'package:avokaido_app/models/cost_alert_notification.dart';
import 'package:avokaido_app/providers/cost_alert_notification_provider.dart';

void main() {
  group('CostAlertNotificationProvider', () {
    late CostAlertNotificationProvider provider;

    setUp(() {
      provider = CostAlertNotificationProvider();
    });

    test('initial notifications list is empty', () {
      expect(provider.notifications, isEmpty);
    });

    test('addNotification adds a notification', () {
      final notification = CostAlertNotification(
        title: 'High Cost',
        message: 'Cost exceeds threshold',
        cost: 150.0,
        threshold: 100.0,
        date: DateTime.now(),
      );

      provider.addNotification(notification);
      expect(provider.notifications.length, 1);
      expect(provider.notifications.first, notification);
    });

    test('clearNotifications clears all notifications', () {
      final notification1 = CostAlertNotification(
        title: 'Alert 1',
        message: 'Cost too high',
        cost: 200.0,
        threshold: 100.0,
        date: DateTime.now(),
      );

      final notification2 = CostAlertNotification(
        title: 'Alert 2',
        message: 'Cost dangerously high',
        cost: 300.0,
        threshold: 150.0,
        date: DateTime.now(),
      );

      provider.addNotification(notification1);
      provider.addNotification(notification2);
      expect(provider.notifications.length, 2);

      provider.clearNotifications();
      expect(provider.notifications, isEmpty);
    });

    test(
      'checkAndNotify does not add notification if cost is below threshold',
      () {
        provider.checkAndNotify(
          cost: 80.0,
          threshold: 100.0,
          title: 'Cost Alert',
          message: 'Cost is within limits',
        );
        expect(provider.notifications, isEmpty);
      },
    );

    test('checkAndNotify adds notification if cost exceeds threshold', () {
      provider.checkAndNotify(
        cost: 120.0,
        threshold: 100.0,
        title: 'High Cost Alert',
        message: 'Cost exceeds threshold',
      );
      expect(provider.notifications.length, 1);
      final notification = provider.notifications.first;
      expect(notification.cost, 120.0);
      expect(notification.threshold, 100.0);
      expect(notification.title, 'High Cost Alert');
    });
  });
}

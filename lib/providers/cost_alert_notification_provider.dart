import 'package:flutter/foundation.dart';

import '../models/cost_alert_notification.dart';

class CostAlertNotificationProvider extends ChangeNotifier {
  final List<CostAlertNotification> _notifications = [];

  List<CostAlertNotification> get notifications =>
      List.unmodifiable(_notifications);

  void addNotification(CostAlertNotification notification) {
    _notifications.add(notification);
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  /// Checks if the cost exceeds the given threshold and adds a notification if it does.
  void checkAndNotify({
    required double cost,
    required double threshold,
    required String title,
    required String message,
  }) {
    if (cost > threshold) {
      final notification = CostAlertNotification(
        title: title,
        message: message,
        cost: cost,
        threshold: threshold,
        date: DateTime.now(),
      );
      addNotification(notification);
    }
  }
}

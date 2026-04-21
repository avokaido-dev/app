import 'package:flutter/foundation.dart';

@immutable
class CostAlertNotification {
  final String title;
  final String message;
  final double cost;
  final double threshold;
  final DateTime date;

  const CostAlertNotification({
    required this.title,
    required this.message,
    required this.cost,
    required this.threshold,
    required this.date,
  });
}

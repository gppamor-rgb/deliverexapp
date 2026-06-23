import '../core/formatters.dart';
import '../core/helpers.dart';

class DriverNotification {
  const DriverNotification(this.raw);

  final Map<String, dynamic> raw;

  String get id => stringValue(raw['id']);
  String get title => firstString([raw['title'], raw['type'], raw['subject']]);
  String get message =>
      firstString([raw['message'], raw['body'], raw['content']]);
  String get createdAt => formatDeliverexDateTime(
    firstString([raw['created_at'], raw['createdAt']]),
  );
  bool get isRead {
    final readAt = firstString([raw['read_at'], raw['readAt']]);
    final read = raw['read'];
    return readAt.isNotEmpty || read == true || read == 1;
  }

  factory DriverNotification.fromJson(Map<String, dynamic> json) {
    return DriverNotification(json);
  }
}

class DriverNotificationsPage {
  const DriverNotificationsPage({required this.notifications});

  final List<DriverNotification> notifications;

  factory DriverNotificationsPage.fromJson(dynamic json) {
    final list = extractList(json);
    return DriverNotificationsPage(
      notifications: list
          .whereType<Map>()
          .map(
            (item) =>
                DriverNotification.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}


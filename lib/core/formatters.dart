import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

final _deliverexDateTimeFormat = DateFormat('MMMM d, yyyy h:mma');
final _deliverexDateFormat = DateFormat('MMMM d, yyyy');
final _deliverexTimeFormat = DateFormat('h:mma');

String formatDeliverexDateTime(dynamic value) {
  final parsed = _parseDateTime(value);
  if (parsed == null) {
    return '—';
  }

  final formatted = _deliverexDateTimeFormat.format(parsed);

  if (kDebugMode) {
    debugPrint(
      'Deliverex datetime format raw=$value parsed=$parsed formatted=$formatted',
    );
  }

  return formatted;
}

String formatDeliverexDate(dynamic value) {
  final parsed = _parseDateTime(value);
  if (parsed == null) {
    return '—';
  }

  final formatted = _deliverexDateFormat.format(parsed);

  if (kDebugMode) {
    debugPrint(
      'Deliverex date format raw=$value parsed=$parsed formatted=$formatted',
    );
  }

  return formatted;
}

String formatDeliverexTime(dynamic value) {
  final parsed = _parseDateTime(value);
  if (parsed == null) {
    return '—';
  }

  final formatted = _deliverexTimeFormat.format(parsed);

  if (kDebugMode) {
    debugPrint(
      'Deliverex time format raw=$value parsed=$parsed formatted=$formatted',
    );
  }

  return formatted;
}

/// Parsing rules:
/// - If backend datetime has Z or timezone offset, parse and convert to local time.
/// - If backend datetime has no timezone, treat it as local time (do NOT toLocal()).
/// - Avoid double-conversion.
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) {
    // If it already has a timezone context, convert to local.
    // If it is already "local", toLocal() is idempotent.
    return value.toLocal();
  }

  final string = value.toString().trim();
  if (string.isEmpty) return null;

  // Detect timezone markers: "Z" or "+HH:MM" / "-HH:MM"
  final hasTimezoneOffset = RegExp(r'([Zz]|[+-]\d{2}:\d{2})$').hasMatch(string);

  final parsed = DateTime.tryParse(string);
  if (parsed == null) return null;

  if (hasTimezoneOffset) {
    // Parsed datetime is in that timezone; convert to local.
    return parsed.toLocal();
  }

  // No timezone info: interpret as local time.
  return parsed;
}

List<dynamic> extractList(dynamic json) {
  if (json is List) {
    return json;
  }
  if (json is Map) {
    final data = json['data'];
    if (data is List) {
      return data;
    }
    if (data is Map && data['data'] is List) {
      return data['data'] as List;
    }
    if (json['assignments'] is List) {
      return json['assignments'] as List;
    }
    if (json['notifications'] is List) {
      return json['notifications'] as List;
    }
  }
  return const [];
}

String stringValue(dynamic value) => value?.toString().trim() ?? '';

String firstString(List<dynamic> values) {
  for (final value in values) {
    final string = stringValue(value);
    if (string.isNotEmpty) {
      return string;
    }
  }
  return '';
}

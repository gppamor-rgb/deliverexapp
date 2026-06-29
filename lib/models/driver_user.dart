class DriverUser {
  const DriverUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roleName,
    this.mustChangePassword = false,
  });

  final String id;
  final String name;
  final String email;
  final String roleName;
  final bool mustChangePassword;

  bool get isDriver {
    final normalized = roleName.toLowerCase().trim();
    if (normalized.isEmpty) {
      return true;
    }
    return normalized.contains('driver') || normalized.contains('delivery');
  }

  factory DriverUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final roleName = role is Map<String, dynamic>
        ? _firstString([
            role['name'],
            role['title'],
            role['slug'],
            role['type'],
            role['code'],
          ])
        : _firstString([
            json['role_name'],
            json['role'],
            json['role_title'],
            json['role_slug'],
            json['role_type'],
          ]);

    return DriverUser(
      id: json['id']?.toString() ?? '',
      name: () {
        final raw = json['name']?.toString().trim();
        if (raw != null && raw.isNotEmpty) return raw;
        final first = json['first_name']?.toString().trim() ?? '';
        final last = json['last_name']?.toString().trim() ?? '';
        final joined = [first, last].where((s) => s.isNotEmpty).join(' ');
        return joined.isNotEmpty ? joined : 'User';
      }(),
      email: json['email']?.toString() ?? '',
      roleName: roleName,
      mustChangePassword: _boolValue(json['must_change_password']),
    );
  }
}

String _firstString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

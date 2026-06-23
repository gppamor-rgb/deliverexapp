class CustomerUser {
  const CustomerUser({
    required this.id,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.email,
    this.mobile,
    required this.role,
  });

  final String id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String email;
  final String? mobile;
  final String role;

  String get fullName => [
    firstName,
    if (middleName != null && middleName!.isNotEmpty) middleName,
    lastName,
  ].join(' ');

  bool get isCustomer => role.toLowerCase().contains('customer');

  factory CustomerUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final roleName = role is Map<String, dynamic>
        ? (role['name']?.toString() ?? 'customer')
        : (json['role']?.toString() ?? 'customer');

    return CustomerUser(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      middleName: json['middle_name']?.toString(),
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      role: roleName,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/helpers.dart';
import '../core/transitions.dart';
import '../models/driver_assignment.dart';
import '../models/driver_user.dart';
import '../repositories/assignment_repository.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_empty_state.dart';
import '../widgets/driver/driver_job_card.dart';
import '../widgets/driver/driver_primary_button.dart';
import '../widgets/driver/driver_status_chip.dart';
import 'job_detail_screen.dart';
import 'start_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final DriverUser user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _driverService = DriverService();
  final _authService = AuthService();
  final _assignmentRepo = AssignmentRepository();
  late Future<_ProfileData> _future;
  var _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileData> _load() async {
    final assignments = await _assignmentRepo.fetchAssignments(page: 1);

    DriverProfile profile;
    try {
      profile = await _driverService.fetchProfile(historyPage: 1);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Deliverex profile: profile fetch failed: $e');
      }
      profile = DriverProfile({});
    }

    return _ProfileData(
      profile: profile,
      assignments: assignments,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfileData>(
      future: _future,
      builder: (context, snapshot) {
        final profile = snapshot.data?.profile;
        final assignments =
            snapshot.data?.assignments ?? const <DriverAssignment>[];
        final raw = profile?.driver ?? const <String, dynamic>{};
        final vehicle = profile?.vehicle ?? const <String, dynamic>{};
        final stats = DriverStats.fromAssignments(assignments);
        final current = _firstActive(assignments);
        final history = assignments.where((item) => item.isCompleted).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            DriverCard(
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stringValue(raw['name']).ifBlank(widget.user.name),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        DriverStatusChip(
                          label: stringValue(
                            raw['availability'],
                          ).ifBlank('Offline'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DriverCard(
              child: Column(
                children: [
                  _InfoLine(
                    icon: Icons.mail_outline,
                    text: stringValue(raw['email']).ifBlank(widget.user.email),
                  ),
                  const SizedBox(height: 8),
                  _InfoLine(
                    icon: Icons.phone_outlined,
                    text: stringValue(
                      raw['phone'],
                    ).ifBlank('No contact number'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ProfileStat(value: assignments.length, label: 'TOTAL'),
                const SizedBox(width: 8),
                _ProfileStat(value: stats.completed, label: 'DONE'),
                const SizedBox(width: 8),
                _ProfileStat(value: stats.pending, label: 'PENDING'),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: profile == null
                  ? null
                  : () => _showEditProfileSheet(raw),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (snapshot.hasError)
              DriverEmptyState(
                title: 'Unable to load profile',
                message: snapshot.error.toString(),
                icon: Icons.cloud_off_outlined,
              )
            else ...[
              const _SectionTitle('ASSIGNED VEHICLE'),
              DriverCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${vehicle['plate_no'] ?? '-'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${vehicle['type'] ?? 'Vehicle'} · ${vehicle['status'] ?? 'inactive'}',
                            style: const TextStyle(color: AppColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle('CURRENT ASSIGNMENT'),
              if (current == null)
                const DriverEmptyState(
                  title: 'No current assignment',
                  message: 'Active assignments will appear here.',
                )
              else
                DriverCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            current.displayJobNumber,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          DriverStatusChip(label: current.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        current.dropoffAddress,
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _openAssignment(current),
                        icon: const Text('View details'),
                        label: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              _SectionTitle('DELIVERY HISTORY (${history.length})'),
              if (history.isEmpty)
                const DriverEmptyState(
                  title: 'No delivery history',
                  message: 'Completed deliveries will appear here.',
                )
              else
                for (final assignment in history)
                  DriverJobCard(
                    job: assignment,
                    onTap: () => _openAssignment(assignment),
                  ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loggingOut ? null : _logout,
                icon: const Icon(Icons.logout_rounded),
                label: Text(_loggingOut ? 'Logging out...' : 'Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  DriverAssignment? _firstActive(List<DriverAssignment> assignments) {
    for (final assignment in assignments) {
      if (assignment.isActive) return assignment;
    }
    return null;
  }

  void _openAssignment(DriverAssignment assignment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(assignmentId: assignment.id),
      ),
    );
  }

  Future<void> _showEditProfileSheet(Map<String, dynamic> raw) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        initialName: stringValue(raw['name']).ifBlank(widget.user.name),
        initialPhone: stringValue(raw['phone']),
        onSubmit: (name, phone) async {
          await _driverService.updateProfile(name: name, phone: phone);
        },
      ),
    );

    if (updated == true && mounted) {
      setState(() => _future = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await _authService.logout();
      if (!mounted) {
        return;
      }
      AppTransitions.pushAndClear(context, const StartScreen());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }
}

class _ProfileData {
  const _ProfileData({required this.profile, required this.assignments});

  final DriverProfile profile;
  final List<DriverAssignment> assignments;
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.mutedText, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

typedef _EditProfileSubmit = Future<void> Function(String name, String phone);

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.initialName,
    required this.initialPhone,
    required this.onSubmit,
  });

  final String initialName;
  final String initialPhone;
  final _EditProfileSubmit onSubmit;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(_nameController.text, _phoneController.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Edit Profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      hintText: '+63...',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  DriverPrimaryButton(
                    label: 'Save Profile',
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.surfaceSoft,
                        foregroundColor: AppColors.text,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

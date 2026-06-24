import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/driver_assignment.dart';
import '../models/driver_user.dart';
import '../repositories/assignment_repository.dart';
import '../services/driver_service.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_empty_state.dart';
import '../widgets/driver/driver_job_card.dart';
import '../widgets/driver/driver_status_chip.dart';
import '../widgets/shimmer_loading.dart';
import 'job_detail_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, required this.user});

  final DriverUser user;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _assignmentRepo = AssignmentRepository();
  final _driverService = DriverService();
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final assignments = await _assignmentRepo.fetchAssignments(page: 1);
    var profile = DriverProfile({});

    try {
      profile = await _driverService.fetchProfile(historyPage: 1);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Deliverex driver_home: profile fetch failed: $e');
      }
    }

    if (kDebugMode) {
      debugPrint(
        'Deliverex driver_home: fetched ${assignments.length} assignments',
      );
      for (final a in assignments) {
        debugPrint(
          '  -> id=${a.id} publicId=${a.publicId} status=${a.status} isActive=${a.isActive} isPending=${a.isPending}',
        );
      }
    }
    return _HomeData(
      assignments: assignments,
      profile: profile,
    );
  }

  Future<void> _refresh() async {
    final refreshedFuture = _load();
    setState(() {
      _future = refreshedFuture;
    });
    await refreshedFuture;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.split(' ').first.ifBlank('Driver');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final assignments = data?.assignments ?? const <DriverAssignment>[];
          final stats = DriverStats.fromAssignments(assignments);
          final active = _firstActive(assignments);
          final todayJobs = _todayJobs(assignments);
          final upcoming = assignments
              .where((a) => (a.isActive || a.isPending) && a.id != active?.id)
              .take(5)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Hello, $firstName',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(
                stats.pending == 1
                    ? 'You have 1 active delivery today.'
                    : 'You have ${stats.pending} active deliveries today.',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _HomeStat(value: stats.jobsToday, label: 'TODAY'),
                  const SizedBox(width: 8),
                  _HomeStat(value: stats.pending, label: 'PENDING'),
                  const SizedBox(width: 8),
                  _HomeStat(value: stats.completed, label: 'DONE'),
                ],
              ),
              const SizedBox(height: 22),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                ShimmerLoading(
                  child: Row(
                    children: const [
                      Expanded(child: SkeletonStatCard()),
                      SizedBox(width: 8),
                      Expanded(child: SkeletonStatCard()),
                      SizedBox(width: 8),
                      Expanded(child: SkeletonStatCard()),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const ShimmerLoading(child: SkeletonCard()),
                const ShimmerLoading(child: SkeletonCard()),
              ],
              if (snapshot.hasError)
                DriverEmptyState(
                  title: 'Unable to load driver home',
                  message: snapshot.error.toString(),
                  icon: Icons.cloud_off_outlined,
                )
              else ...[
                Text('CURRENT DELIVERY', style: _sectionStyle),
                const SizedBox(height: 12),
                if (active == null)
                  const DriverEmptyState(
                    title: 'No active delivery',
                    message: 'New assignments will appear here.',
                  )
                else
                  _CurrentDeliveryCard(assignment: active),
                if ((data?.profile.vehicle ?? const {}).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _VehicleCard(vehicle: data!.profile.vehicle),
                ],
                if (todayJobs.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    "Today's assigned deliveries",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final assignment in todayJobs)
                    DriverJobCard(
                      job: assignment,
                      onTap: () => _openAssignment(assignment),
                    ),
                ],
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Upcoming',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final assignment in upcoming)
                    DriverJobCard(
                      job: assignment,
                      onTap: () => _openAssignment(assignment),
                    ),
                ],
                if (assignments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: DriverEmptyState(
                      title: 'No assignments',
                      message:
                          'Assigned deliveries from the website will show here.',
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<DriverAssignment> _todayJobs(List<DriverAssignment> assignments) {
    final now = DateTime.now();
    return assignments.where((assignment) {
      final scheduled = assignment.jobOrder['scheduled_start']?.toString();
      if (scheduled == null || scheduled.isEmpty) {
        return assignment.isActive || assignment.isPending;
      }
      final date = DateTime.tryParse(scheduled)?.toLocal();
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
  }

  void _openAssignment(DriverAssignment assignment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(assignmentId: assignment.id),
      ),
    ).then((_) => _refresh());
  }

  DriverAssignment? _firstActive(List<DriverAssignment> assignments) {
    for (final assignment in assignments) {
      if (assignment.isActive) {
        return assignment;
      }
    }
    return null;
  }
}

const _sectionStyle = TextStyle(
  color: AppColors.mutedText,
  fontSize: 12,
  fontWeight: FontWeight.w900,
  letterSpacing: 0.8,
);

class _HomeStat extends StatelessWidget {
  const _HomeStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.text.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
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

class _CurrentDeliveryCard extends StatelessWidget {
  const _CurrentDeliveryCard({required this.assignment});

  final DriverAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff234fc4), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ACTIVE NOW',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              DriverStatusChip(
                label: assignment.status,
                color: const Color(0xffffb020),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            assignment.publicId,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            assignment.displayName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 8),
          _HeroLine(
            icon: Icons.place_outlined,
            text: assignment.dropoffAddress,
          ),
          const SizedBox(height: 8),
          _HeroLine(icon: Icons.event_outlined, text: assignment.schedule),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JobDetailScreen(assignmentId: assignment.id),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.38)),
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Continue delivery'),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assigned vehicle',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${vehicle['plate_no'] ?? '-'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${vehicle['type'] ?? 'Vehicle'}',
                  style: const TextStyle(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData({required this.assignments, required this.profile});

  final List<DriverAssignment> assignments;
  final DriverProfile profile;
}

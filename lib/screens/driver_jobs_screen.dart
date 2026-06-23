import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/driver_assignment.dart';
import '../repositories/assignment_repository.dart';
import '../widgets/driver/driver_empty_state.dart';
import '../widgets/driver/driver_job_card.dart';
import 'job_detail_screen.dart';

class DriverJobsScreen extends StatefulWidget {
  const DriverJobsScreen({super.key});

  @override
  State<DriverJobsScreen> createState() => _DriverJobsScreenState();
}

class _DriverJobsScreenState extends State<DriverJobsScreen> {
  final _assignmentRepo = AssignmentRepository();
  var _filter = 'active';
  late Future<List<DriverAssignment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DriverAssignment>> _load() async {
    return _assignmentRepo.fetchAssignments(page: 1);
  }

  Future<void> _refresh() async {
    final refreshedFuture = _load();
    setState(() {
      _future = refreshedFuture;
    });
    await refreshedFuture;
  }

  List<DriverAssignment> _filterAssignments(
    List<DriverAssignment> assignments,
  ) {
    return assignments.where((assignment) {
      if (_filter == 'active') {
        return assignment.isActive || assignment.isPending;
      }
      if (_filter == 'completed') {
        return assignment.isCompleted;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<DriverAssignment>>(
        future: _future,
        builder: (context, snapshot) {
          final assignments = snapshot.data ?? const <DriverAssignment>[];
          final jobs = _filterAssignments(assignments);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Your assigned deliveries',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final filter in const [
                    ('active', 'Active'),
                    ('completed', 'Completed'),
                    ('all', 'All'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.$2),
                        selected: _filter == filter.$1,
                        onSelected: (_) => setState(() => _filter = filter.$1),
                        selectedColor: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        labelStyle: TextStyle(
                          color: _filter == filter.$1
                              ? AppColors.primary
                              : AppColors.mutedText,
                          fontWeight: FontWeight.w800,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting)
                const _JobsLoading()
              else if (snapshot.hasError)
                DriverEmptyState(
                  title: 'Unable to load jobs',
                  message: snapshot.error.toString(),
                  icon: Icons.cloud_off_outlined,
                )
              else if (jobs.isEmpty)
                DriverEmptyState(
                  title: 'No jobs found',
                  message: _filter == 'active'
                      ? 'You have no active deliveries.'
                      : 'Nothing for this filter.',
                )
              else
                for (final job in jobs)
                  DriverJobCard(
                    job: job,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JobDetailScreen(assignmentId: job.id),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _JobsLoading extends StatelessWidget {
  const _JobsLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LinearProgressIndicator(),
        SizedBox(height: 14),
        DriverEmptyState(
          title: 'Loading assignments',
          message: 'Fetching your assigned deliveries from Deliverex.',
          icon: Icons.sync_rounded,
        ),
      ],
    );
  }
}

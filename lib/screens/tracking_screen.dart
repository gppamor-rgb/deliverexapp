import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/delivery_status.dart';
import '../models/delivery_tracking_result.dart';
import '../models/driver_assignment.dart';
import '../services/tracking_service.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_empty_state.dart';
import '../widgets/driver/driver_status_chip.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    super.key,
    this.prefillTracking,
    this.trackingService,
    this.showBackButton = true,
  });

  final String? prefillTracking;
  final TrackingService? trackingService;
  final bool showBackButton;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final TextEditingController _controller;
  late final TrackingService _trackingService;
  DeliveryTrackingResult? _result;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _trackingService = widget.trackingService ?? TrackingService();
    _controller = TextEditingController(text: widget.prefillTracking ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup([String? value]) async {
    final trackingCode = (value ?? _controller.text).trim();
    if (trackingCode.isEmpty) {
      setState(() {
        _error = 'Enter a tracking ID.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _trackingService.lookup(trackingCode);
      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } on TrackingLookupException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _result = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _result = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openMaps(DeliveryTrackingResult result) async {
    final latitude = result.dropoffLatitude;
    final longitude = result.dropoffLongitude;
    final address = result.dropoffAddress;

    final uri = latitude != null && longitude != null
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
          );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        centerTitle: true,
        title: const Text('Track Delivery'),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DriverCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Track your delivery',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Monitor delivery progress, estimated arrival, and proof-of-delivery information without signing in.',
                    style: TextStyle(color: AppColors.mutedText, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _lookup,
                    decoration: const InputDecoration(
                      labelText: 'Tracking ID',
                      hintText: 'Example: XKFP2NQRLA',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _lookup,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(_loading ? 'Tracking...' : 'Track'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No account required',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              DriverCard(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (_result == null)
              const DriverEmptyState(
                title: 'Delivery status',
                message:
                    'Enter a tracking ID to view the current status, ETA window, and proof-of-delivery details.',
                icon: Icons.local_shipping_outlined,
              )
            else ...[
              _StatusSummaryCard(result: _result!),
              const SizedBox(height: 16),
              _RouteCard(
                result: _result!,
                onOpenMaps: () => _openMaps(_result!),
              ),
              const SizedBox(height: 16),
              _ProofCard(result: _result!),
              const SizedBox(height: 16),
              _ActivityCard(result: _result!),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  const _StatusSummaryCard({required this.result});

  final DeliveryTrackingResult result;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _statusIndex(result.status);
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.trackingCode,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.statusLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              DriverStatusChip(label: result.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                icon: Icons.schedule_rounded,
                label: 'ETA',
                value: result.etaLabel,
              ),
              _InfoPill(
                icon: Icons.person_outline,
                label: 'Customer',
                value: result.customerName,
              ),
              if (result.lastUpdated != null)
                _InfoPill(
                  icon: Icons.update_rounded,
                  label: 'Last update',
                  value: result.lastUpdated!,
                ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  SizedBox(
                    width: 108,
                    child: _TimelineStep(
                      label: _steps[i].$2,
                      sublabel: i == currentIndex ? _steps[i].$2 : null,
                      icon: _steps[i].$3,
                      active: i == currentIndex,
                      complete: i < currentIndex,
                    ),
                  ),
                  if (i < _steps.length - 1)
                    SizedBox(
                      width: 20,
                      child: Container(
                        margin: const EdgeInsets.only(top: 17),
                        height: 2,
                        color: i < currentIndex
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : AppColors.border,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _steps = [
    ('assigned', 'Assigned', Icons.check_rounded),
    ('en_route_to_pickup', 'En Route to Pickup', Icons.local_shipping_rounded),
    ('arrived_at_pickup', 'Arrived at Pickup', Icons.warehouse_rounded),
    ('en_route_to_destination', 'En Route to Destination', Icons.route_rounded),
    ('arrived', 'Arrived', Icons.location_on_rounded),
    ('completed', 'Completed', Icons.check_circle_rounded),
  ];

  int _statusIndex(String status) {
    return deliveryStatusIndex(status);
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.active,
    required this.complete,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final IconData icon;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primary
        : complete
        ? AppColors.success
        : AppColors.mutedText;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : complete
                ? AppColors.success.withValues(alpha: 0.16)
                : AppColors.surfaceSoft,
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : complete
                  ? AppColors.success
                  : AppColors.border,
              width: 2,
            ),
          ),
          child: Icon(icon, color: active ? Colors.white : color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          softWrap: true,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (sublabel != null)
          Text(
            sublabel!,
            textAlign: TextAlign.center,
            softWrap: true,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.result, required this.onOpenMaps});

  final DeliveryTrackingResult result;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _KeyValueRow(label: 'Pickup', value: result.pickupAddress),
          _KeyValueRow(label: 'Drop-off', value: result.dropoffAddress),
          _KeyValueRow(label: 'Schedule', value: result.schedule),
          _KeyValueRow(label: 'Vehicle', value: result.vehicleLabel),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: result.dropoffAddress == '—' ? null : onOpenMaps,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Open in Maps'),
          ),
        ],
      ),
    );
  }
}

class _ProofCard extends StatelessWidget {
  const _ProofCard({required this.result});

  final DeliveryTrackingResult result;

  @override
  Widget build(BuildContext context) {
    final proof = result.completionProof;
    if (proof == null) {
      return const DriverEmptyState(
        title: 'Proof of delivery',
        message: 'No proof-of-delivery document has been attached yet.',
        icon: Icons.receipt_long_outlined,
      );
    }

    final url = _firstString([
      proof['file_url'],
      proof['url'],
      proof['document_url'],
      proof['proof_url'],
    ]);

    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proof of delivery',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _KeyValueRow(
            label: 'Type',
            value: _firstString([
              proof['proof_type'],
              proof['type'],
              proof['document_type'],
            ]).ifBlank('—'),
          ),
          _KeyValueRow(
            label: 'Receiver',
            value: _firstString([
              proof['receiver_name'],
              proof['received_by'],
              proof['contact_name'],
            ]).ifBlank('—'),
          ),
          _KeyValueRow(
            label: 'Contact',
            value: _firstString([
              proof['receiver_contact'],
              proof['contact_number'],
            ]).ifBlank('—'),
          ),
          _KeyValueRow(
            label: 'Notes',
            value: _firstString([
              proof['delivery_notes'],
              proof['notes'],
            ]).ifBlank('—'),
          ),
          if (url.isNotEmpty) ...[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open proof file'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.result});

  final DeliveryTrackingResult result;

  @override
  Widget build(BuildContext context) {
    final visibleLogs = result.trackingLogs.take(5).toList();
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tracking activity',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (visibleLogs.isEmpty)
            const Text(
              'No status updates have been recorded yet.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            Column(
              children: [
                for (var index = 0; index < visibleLogs.length; index++) ...[
                  _ActivityRow(log: visibleLogs[index]),
                  if (index < visibleLogs.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final status = _firstString([
      log['status'],
      log['type'],
      log['event_type'],
      log['label'],
    ]).ifBlank('Update');
    final timestamp = _firstString([
      log['captured_at'],
      log['created_at'],
      log['updated_at'],
      log['timestamp'],
      log['time'],
    ]);
    final message = _firstString([
      log['message'],
      log['notes'],
      log['description'],
    ]);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (timestamp.isNotEmpty)
                Text(
                  timestamp,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(color: AppColors.mutedText)),
          ],
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _firstString(List<dynamic> values) {
  for (final value in values) {
    final string = value?.toString().trim() ?? '';
    if (string.isNotEmpty) {
      return string;
    }
  }
  return '';
}

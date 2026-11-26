import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Lets either participant report an issue tied to a specific booking.
class BookingReportButton extends StatelessWidget {
  const BookingReportButton({
    super.key,
    required this.booking,
    required this.isProfessional,
  });

  final Map<String, dynamic> booking;
  final bool isProfessional;

  Future<void> _openForm(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // This button can be inside the professional's request bottom sheet.
      // Present the report form on the root navigator to avoid nesting modal
      // routes in the sheet's navigator and tearing down inherited elements
      // while the parent request sheet is still mounted.
      useRootNavigator: true,
      builder: (_) =>
          _BookingReportForm(booking: booking, isProfessional: isProfessional),
    );

    if (submitted == true && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('booking_report_success'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => _openForm(context),
      icon: const Icon(Icons.flag_outlined),
      label: Text('booking_report_action'.tr()),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0D544E),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
  );
}

class _BookingReportForm extends StatefulWidget {
  const _BookingReportForm({
    required this.booking,
    required this.isProfessional,
  });

  final Map<String, dynamic> booking;
  final bool isProfessional;

  @override
  State<_BookingReportForm> createState() => _BookingReportFormState();
}

class _BookingReportFormState extends State<_BookingReportForm> {
  static const _clientReasons = <String>[
    'booking_report_client_communication',
    'booking_report_pro_absence',
    'booking_report_work_quality',
    'booking_report_payment',
    'booking_report_safety',
    'booking_report_other',
  ];
  static const _proReasons = <String>[
    'booking_report_client_behavior',
    'booking_report_client_absence',
    'booking_report_address_issue',
    'booking_report_payment',
    'booking_report_safety',
    'booking_report_other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  late final List<String> _reasons;
  late String _selectedReason;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _reasons = widget.isProfessional ? _proReasons : _clientReasons;
    _selectedReason = _reasons.first;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('booking_report_sign_in_required'.tr());
      }

      final booking = widget.booking;
      final clientId = booking['clientId']?.toString() ?? '';
      final proId = booking['proId']?.toString() ?? '';
      final reporterName = widget.isProfessional
          ? (booking['proName']?.toString() ?? 'pro_req_professional'.tr())
          : (booking['clientName']?.toString() ?? 'pro_req_client'.tr());
      final targetId = widget.isProfessional ? clientId : proId;
      final targetName = widget.isProfessional
          ? (booking['clientName']?.toString() ?? 'pro_req_client'.tr())
          : (booking['proName']?.toString() ?? 'pro_req_professional'.tr());
      final selectedReasonLabel = _selectedReason.tr();

      await FirebaseFirestore.instance.collection('reports').add({
        'type': 'booking_report',
        'title': '${'booking_report_title'.tr()} · $selectedReasonLabel',
        'category': selectedReasonLabel,
        'description': _descriptionController.text.trim(),
        'bookingId': booking['id']?.toString() ?? '',
        'reporterId': user.uid,
        'reporterName': reporterName,
        'reporterRole': widget.isProfessional ? 'professionnel' : 'client',
        'targetId': targetId,
        'targetName': targetName,
        'targetRole': widget.isProfessional ? 'client' : 'professionnel',
        'clientId': clientId,
        'clientName':
            booking['clientName']?.toString() ?? 'pro_req_client'.tr(),
        'proId': proId,
        'proName':
            booking['proName']?.toString() ?? 'pro_req_professional'.tr(),
        'serviceType': booking['serviceType']?.toString() ?? '',
        'status': 'Ouvert',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = 'booking_report_send_error'.tr(
          namedArgs: {'error': error.toString()},
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'booking_report_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('booking_report_intro'.tr()),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                validator: (value) =>
                    value == null ? 'report_reason_required'.tr() : null,
                decoration: InputDecoration(
                  labelText: 'booking_report_reason'.tr(),
                  border: OutlineInputBorder(),
                ),
                items: _reasons
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(reason.tr()),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _selectedReason = value;
                            _submitError = null;
                          });
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isSubmitting,
                maxLength: 1000,
                maxLines: 4,
                validator: (value) =>
                    _selectedReason == 'booking_report_other' &&
                        (value ?? '').trim().isEmpty
                    ? 'report_other_description_required'.tr()
                    : null,
                decoration: InputDecoration(
                  labelText: 'booking_report_details'.tr(),
                  hintText: 'booking_report_details_hint'.tr(),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _submitError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag_outlined),
                  label: Text(
                    _isSubmitting
                        ? 'booking_report_sending'.tr()
                        : 'booking_report_send'.tr(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

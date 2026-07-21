import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'patient_visit_screen.dart';

/// Add a patient — mirrors the web app's "Schedule New Patient": name + MRN
/// (required), date of birth (optional), and a visit type. In live mode this
/// creates the patient and an initial visit so they appear for the clinician.
class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mrn = TextEditingController();
  DateTime? _dob;
  String _visitType = 'New Patient';
  // Visit date/time default to now, but the clinician can change them.
  DateTime _visitDate = DateTime.now();
  TimeOfDay _visitTime = TimeOfDay.now();
  bool _saving = false;

  static const _visitTypes = ['Follow-up', 'New Patient', 'Virtual Visit', 'Other'];

  @override
  void dispose() {
    _name.dispose();
    _mrn.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _hm24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickVisitDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Visit date',
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  Future<void> _pickVisitTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _visitTime,
      helpText: 'Visit time',
    );
    if (picked != null) setState(() => _visitTime = picked);
  }

  /// Saves the patient. When [thenRecord] is true, jumps straight into capturing
  /// their visit (skips returning to the list and hunting for the new card).
  Future<void> _save({bool thenRecord = false}) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final ok = await state.addPatient(
      name: _name.text,
      mrn: _mrn.text,
      dob: _dob == null ? null : _ymd(_dob!),
      visitType: _visitType,
      visitDate: _ymd(_visitDate),
      visitTime: _hm24(_visitTime),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      final id = state.lastAddedPatientId;
      if (thenRecord && id != null) {
        // Replace this screen so Back returns to the list, not the form.
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) =>
                PatientVisitScreen(patientId: id, autoStart: true)));
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Patient added.')));
      Navigator.of(context).pop();
    } else if (state.adminMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.adminMessage!)));
      state.clearAdminMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Clinic.backgroundLight,
      appBar: AppBar(
        title: const Text('Add Patient',
            style: TextStyle(fontWeight: FontWeight.bold, color: Clinic.brandNavy)),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(_name, 'Full name', required: true, autofocus: true),
            _field(_mrn, 'MRN (medical record number)', required: true),
            // Date of birth (optional)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                onTap: _pickDob,
                borderRadius: BorderRadius.circular(Clinic.rControl),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of birth (optional)',
                    suffixIcon: const Icon(Icons.calendar_today,
                        size: 18, color: Clinic.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Clinic.rControl)),
                  ),
                  child: Text(
                    _dob == null ? 'Select date' : _ymd(_dob!),
                    style: TextStyle(
                        color: _dob == null
                            ? Clinic.secondary.withValues(alpha: 0.6)
                            : Clinic.secondary),
                  ),
                ),
              ),
            ),
            // Visit type
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                initialValue: _visitType,
                decoration: InputDecoration(
                  labelText: 'Visit type',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Clinic.rControl)),
                ),
                items: _visitTypes
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _visitType = v ?? _visitType),
              ),
            ),
            // Visit date + time (when the encounter is / will be).
            Row(
              children: [
                Expanded(
                  child: _pickerField(
                    label: 'Visit date',
                    value: _ymd(_visitDate),
                    icon: Icons.event,
                    onTap: _pickVisitDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerField(
                    label: 'Visit time',
                    value: _visitTime.format(context),
                    icon: Icons.access_time,
                    onTap: _pickVisitTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Clinic.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Clinic.rControl)),
                ),
                onPressed: _saving ? null : () => _save(thenRecord: true),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.mic),
                label: Text(_saving ? 'Saving…' : 'Save & record',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Clinic.primary,
                  side: const BorderSide(color: Clinic.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Clinic.rControl)),
                ),
                onPressed: _saving ? null : () => _save(),
                icon: const Icon(Icons.person_add),
                label: const Text('Save patient',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A read-only field that opens a picker (used for visit date + time).
  Widget _pickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Clinic.rControl),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(icon, size: 18, color: Clinic.primary),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(Clinic.rControl)),
          ),
          child: Text(value, style: const TextStyle(color: Clinic.secondary)),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, bool autofocus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        autofocus: autofocus,
        textInputAction: TextInputAction.next,
        style: const TextStyle(color: Clinic.secondary),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Clinic.rControl)),
        ),
      ),
    );
  }
}

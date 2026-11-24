import 'package:flutter/material.dart';

import '../services/ros_service.dart';

/// Lets the user configure the mower's start time, active days, and duration.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  final Set<String> _selectedDays = {'Mon', 'Wed', 'Fri'}; // Default selection
  int _mowingDurationHours = 4;
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFromMower(rosService.mowerSchedule);
  }

  /// Starts from the schedule saved on the mower (sent in its status). The first time slot gives
  /// the start time and duration; without any slot the defaults above stay.
  void _loadFromMower(Map<String, dynamic>? schedule) {
    if (schedule == null) return;
    _enabled = schedule['enabled'] as bool? ?? false;
    final days = schedule['days'];
    if (days is! Map) return;
    final selected = <String>{};
    Map? firstSlot;
    for (int i = 0; i < _weekDays.length; i++) {
      final slots = days['$i'];
      if (slots is List && slots.isNotEmpty && slots.first is Map) {
        selected.add(_weekDays[i]);
        firstSlot ??= slots.first as Map;
      }
    }
    if (firstSlot == null) return;
    _selectedDays
      ..clear()
      ..addAll(selected);
    final start = _parseTime(firstSlot['start']);
    final end = _parseTime(firstSlot['end']);
    if (start != null) _selectedTime = start;
    if (start != null && end != null) {
      final minutes =
          (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
      _mowingDurationHours = (minutes / 60).round().clamp(1, 12).toInt();
    }
  }

  /// "HH:MM" from the mower, or null.
  static TimeOfDay? _parseTime(dynamic value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Opens the platform time picker and stores the selected start time.
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  /// Adds or removes a weekday from the schedule selection.
  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  /// Sends the schedule and shows the mower's answer; closes the screen once it is saved.
  Future<void> _save() async {
    setState(() => _saving = true);
    final (saved, message) = await rosService.saveSchedule(
      _selectedDays.toList(),
      _selectedTime,
      _mowingDurationHours,
      enabled: _enabled,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    if (saved) Navigator.pop(context); // Return to the dashboard.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Schedule")),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Mow by schedule",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _enabled
                        ? "The mower starts by itself in these time slots"
                        : "Off: the mower only mows when you start it",
                  ),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Select Start Time",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.access_time),
                    label: Text(
                      _selectedTime.format(context),
                      style: const TextStyle(fontSize: 24),
                    ),
                    onPressed: _pickTime,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                const Text(
                  "Select Days of the Week",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _weekDays.map((day) {
                    final isSelected = _selectedDays.contains(day);
                    return ChoiceChip(
                      label: Text(day),
                      selected: isSelected,
                      onSelected: (_) => _toggleDay(day),
                      selectedColor: Colors.green.withValues(alpha: 0.3),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 30),
                const Text(
                  "Select Mowing Duration per Day",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.greenAccent),
                    const SizedBox(width: 12),
                    Text(
                      "$_mowingDurationHours hours / day",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _mowingDurationHours.toDouble(),
                  min: 1.0,
                  max: 12.0,
                  divisions: 11,
                  label: "$_mowingDurationHours hours",
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      _mowingDurationHours = val.toInt();
                    });
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text(
                  "Save Schedule",
                  style: TextStyle(fontSize: 18),
                ),
                onPressed: _saving ? null : _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

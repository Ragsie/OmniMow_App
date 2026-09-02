import 'package:flutter/material.dart';
import '../services/ros_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<String> _selectedDays = {'Mon', 'Wed', 'Fri'}; // Default selection

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

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Schedule")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Start Time", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Center(
              child: ActionChip(
                avatar: const Icon(Icons.access_time),
                label: Text(_selectedTime.format(context), style: const TextStyle(fontSize: 24)),
                onPressed: _pickTime,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            const SizedBox(height: 30),

            const Text("Select Weekdays", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  selectedColor: Colors.green.withOpacity(0.3),
                );
              }).toList(),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Save Schedule", style: TextStyle(fontSize: 18)),
                onPressed: () {
                  rosService.saveSchedule(_selectedDays.toList(), _selectedTime);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Schedule saved and sent to the mower!")),
                  );
                  Navigator.pop(context); // Return to the dashboard
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
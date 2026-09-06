import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../data/admin_repository.dart';
import '../../auth/presentation/auth_provider.dart';

final adminSettingsProvider = FutureProvider.autoDispose((ref) async {
  final repo = AdminRepository();
  return await repo.getSettings();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _priceCtrl;
  late TextEditingController _startTimeCtrl;
  late TextEditingController _endTimeCtrl;
  late TextEditingController _cutoffCtrl;
  late TextEditingController _maxDaysCtrl;
  List<String> _weekendDays = ['Friday', 'Saturday'];
  bool _allowCancellation = true;
  bool _isSaving = false;
  bool _initialized = false;

  final List<String> _allDays = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController();
    _startTimeCtrl = TextEditingController();
    _endTimeCtrl = TextEditingController();
    _cutoffCtrl = TextEditingController();
    _maxDaysCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _cutoffCtrl.dispose();
    _maxDaysCtrl.dispose();
    super.dispose();
  }

  void _initFields(Map<String, dynamic> settings) {
    if (!_initialized) {
      _priceCtrl.text = settings['current_meal_price'].toString();
      _startTimeCtrl.text = settings['attendance_start_time'].toString();
      _endTimeCtrl.text = settings['attendance_end_time'].toString();
      _cutoffCtrl.text = settings['cancellation_cutoff_time'].toString();
      _maxDaysCtrl.text = settings['max_planning_days'].toString();
      _allowCancellation = settings['allow_employee_cancellation'] == true;
      if (settings['weekend_days'] != null && settings['weekend_days'] is List) {
        _weekendDays = List<String>.from(settings['weekend_days']);
      }
      _initialized = true;
    }
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final repo = AdminRepository();
        await repo.updateSettings({
          'company_name': 'Appifly BD Limited',
          'timezone': 'Asia/Dhaka',
          'currency': 'BDT',
          'currency_symbol': '৳',
          'current_meal_price': double.parse(_priceCtrl.text.trim()),
          'attendance_start_time': _startTimeCtrl.text.trim(),
          'attendance_end_time': _endTimeCtrl.text.trim(),
          'cancellation_cutoff_time': _cutoffCtrl.text.trim(),
          'allow_employee_cancellation': _allowCancellation,
          'charge_on_attendance_only': true,
          'max_planning_days': int.parse(_maxDaysCtrl.text.trim()),
          'weekend_days': _weekendDays,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ System settings updated successfully!'), backgroundColor: AppColors.success),
          );
          ref.invalidate(adminSettingsProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading settings...'),
        error: (err, stack) => ErrorRetryWidget(errorMessage: err.toString(), onRetry: () => ref.invalidate(adminSettingsProvider)),
        data: (data) {
          final settings = data['settings'];
          final List priceHistory = data['price_history'] ?? [];
          _initFields(settings);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Meal Price Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          CustomTextField(
                            controller: _priceCtrl,
                            label: 'Meal Price (BDT ৳)',
                            hint: '120.00',
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.attach_money,
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),

                          const Text('Attendance Window (Asia/Dhaka)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          CustomTextField(controller: _startTimeCtrl, label: 'Start Time (HH:MM:SS)', hint: '12:30:00', prefixIcon: Icons.access_time),
                          const SizedBox(height: 12),
                          CustomTextField(controller: _endTimeCtrl, label: 'End Time (HH:MM:SS)', hint: '14:00:00', prefixIcon: Icons.access_time_filled),
                          const SizedBox(height: 20),

                          const Text('Cancellation Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          CustomTextField(controller: _cutoffCtrl, label: 'Cancellation Cutoff Time', hint: '11:00:00', prefixIcon: Icons.alarm_off),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text('Allow Employee Self-Cancellation'),
                            subtitle: const Text('Employees can cancel scheduled lunch before cutoff time'),
                            value: _allowCancellation,
                            onChanged: (val) => setState(() => _allowCancellation = val),
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(controller: _maxDaysCtrl, label: 'Maximum Advance Planning Days', hint: '30', keyboardType: TextInputType.number, prefixIcon: Icons.calendar_month),
                          const SizedBox(height: 20),

                          const Text('Weekend Days Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text('Select official company weekend days:', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _allDays.map((day) {
                              final isSelected = _weekendDays.contains(day);
                              return FilterChip(
                                label: Text(day),
                                selected: isSelected,
                                selectedColor: AppColors.primary.withAlpha(50),
                                checkmarkColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      if (!_weekendDays.contains(day)) _weekendDays.add(day);
                                    } else {
                                      _weekendDays.remove(day);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          CustomButton(
                            text: 'Save Settings',
                            icon: Icons.save_rounded,
                            isLoading: _isSaving,
                            onPressed: _saveSettings,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Price History Table
                  Text('Price Change History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: priceHistory.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final ph = priceHistory[idx];
                        return ListTile(
                          title: Text('৳${ph['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Effective Date: ${ph['effective_date']}\n${ph['notes'] ?? ''}'),
                          isThreeLine: true,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Logout Option Card
                  Card(
                    color: AppColors.error.withOpacity(0.05),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.error.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Options',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign out of your administrator account on this device.',
                            style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => ref.read(authProvider.notifier).logout(),
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

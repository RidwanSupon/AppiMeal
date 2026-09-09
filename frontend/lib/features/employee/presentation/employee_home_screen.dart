import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/employee_avatar.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/employee_repository.dart';

final employeeSummaryProvider = FutureProvider.autoDispose((ref) async {
  final repo = EmployeeRepository();
  return await repo.getEmployeeSummary();
});

final todayListProvider = FutureProvider.autoDispose((ref) async {
  final repo = EmployeeRepository();
  return await repo.getTodayList();
});

class EmployeeHomeScreen extends ConsumerStatefulWidget {
  final Function(int) onTabChange;

  const EmployeeHomeScreen({super.key, required this.onTabChange});

  @override
  ConsumerState<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends ConsumerState<EmployeeHomeScreen> {
  bool _isAttending = false;

  void _attendLunch() async {
    setState(() {
      _isAttending = true;
    });

    try {
      final repo = EmployeeRepository();
      final res = await repo.attendLunch();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? '✓ Lunch attendance recorded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(employeeSummaryProvider);
        ref.invalidate(todayListProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAttending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(employeeSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('AppiMeal', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(employeeSummaryProvider);
              ref.invalidate(todayListProvider);
            },
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading your dashboard...'),
        error: (err, stack) => ErrorRetryWidget(
          errorMessage: err.toString(),
          onRetry: () {
            ref.invalidate(employeeSummaryProvider);
            ref.invalidate(todayListProvider);
          },
        ),
        data: (data) {
          final emp = data['employee'];
          final today = data['today'];
          final window = data['window'];
          final monthly = data['monthly'];

          final isAttended = today['is_attended'] == true;
          final isScheduled = today['is_scheduled'] == true;
          final canAttend = today['can_attend'] == true;
          final isCancelled = today['schedule_status'] == 'CANCELLED';

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(employeeSummaryProvider);
              ref.invalidate(todayListProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header Card
                  Card(
                    color: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              EmployeeAvatar(
                                avatarUrl: emp['avatar_url'],
                                name: emp['name'],
                                radius: 24,
                                backgroundColor: Colors.white24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, ${emp['name']}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${emp['employee_id']} • ${emp['department']}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Today's Lunch Section
                  Text(
                    "Today's Lunch Status",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Schedule Status', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  StatusBadge(status: today['schedule_status'] ?? 'NOT SCHEDULED'),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Attendance Window', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${window['start_time']} - ${window['end_time']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          if (isAttended) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 32),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '✓ Lunch Attended',
                                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      if (today['attendance_time'] != null)
                                        Text(
                                          'Recorded at ${today['attendance_time']}',
                                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isCancelled) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.cancel_rounded, color: AppColors.error, size: 28),
                                  SizedBox(width: 12),
                                  Text(
                                    'Lunch schedule cancelled for today.',
                                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            CustomButton(
                              text: 'ATTEND LUNCH',
                              icon: Icons.touch_app_rounded,
                              isLoading: _isAttending,
                              backgroundColor: canAttend ? AppColors.secondary : Colors.grey,
                              onPressed: canAttend ? _attendLunch : null,
                            ),
                            if (!canAttend && !isScheduled)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Unplanned lunch check-in is allowed only during attendance window.',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Who's Attending Today Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Who's Attending Today",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      ref.watch(todayListProvider).maybeWhen(
                        data: (todayData) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${todayData['total_attended']} / ${todayData['total_scheduled']} Attended',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ref.watch(todayListProvider).when(
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (err, _) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Error loading today\'s list: $err', style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      ),
                    ),
                    data: (todayData) {
                      final List employees = todayData['employees'] ?? [];
                      if (employees.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'No employees scheduled for today yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        );
                      }
                      return Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: employees.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = employees[index];
                            final isAttendedItem = item['is_attended'] == true;
                            final status = item['status'] ?? 'NOT_SCHEDULED';

                            return ListTile(
                              leading: EmployeeAvatar(
                                avatarUrl: item['avatar_url'],
                                name: item['full_name'] ?? 'Employee',
                                radius: 20,
                              ),
                              title: Text(
                                item['full_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${item['department'] ?? ''} • ${item['designation'] ?? ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusBadge(status: status),
                                  if (isAttendedItem && item['attendance_time'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      item['attendance_time'],
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Monthly Summary Cards Grid
                  Text(
                    'This Month Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildMetricCard(
                        'Meals Taken',
                        '${monthly['meals_taken']}',
                        Icons.restaurant_menu_rounded,
                        AppColors.primary,
                      ),
                      _buildMetricCard(
                        'Meals Scheduled',
                        '${monthly['meals_scheduled'] ?? monthly['meals_taken']}',
                        Icons.event_available_rounded,
                        AppColors.secondary,
                      ),
                      _buildMetricCard(
                        'Days Attended',
                        '${monthly['meals_taken']} Days',
                        Icons.verified_rounded,
                        AppColors.success,
                      ),
                      _buildMetricCard(
                        'Lunch Status',
                        'Company Paid',
                        Icons.workspace_premium_rounded,
                        AppColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Action Buttons
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => widget.onTabChange(1), // Plan Lunch Tab
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: const Text('Plan Lunch'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => widget.onTabChange(2), // History Tab
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('Meal History'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

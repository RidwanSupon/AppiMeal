import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/employee_repository.dart';

final calendarMonthProvider = StateProvider.autoDispose<int>((ref) => DateTime.now().month);
final calendarYearProvider = StateProvider.autoDispose<int>((ref) => DateTime.now().year);

final calendarDataProvider = FutureProvider.autoDispose((ref) async {
  final month = ref.watch(calendarMonthProvider);
  final year = ref.watch(calendarYearProvider);
  final repo = EmployeeRepository();
  return await repo.getCalendar(month: month, year: year);
});

class LunchPlanningCalendarScreen extends ConsumerWidget {
  const LunchPlanningCalendarScreen({super.key});

  void _toggleSchedule(BuildContext context, WidgetRef ref, String dateStr, bool currentStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = EmployeeRepository();
      final res = await repo.scheduleLunch(lunchDate: dateStr, participate: !currentStatus);

      messenger.showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Schedule updated.'),
          backgroundColor: AppColors.success,
        ),
      );

      ref.invalidate(calendarDataProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(calendarDataProvider);
    final month = ref.watch(calendarMonthProvider);
    final year = ref.watch(calendarYearProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lunch Planning Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Month Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: () {
                    if (month == 1) {
                      ref.read(calendarMonthProvider.notifier).state = 12;
                      ref.read(calendarYearProvider.notifier).state = year - 1;
                    } else {
                      ref.read(calendarMonthProvider.notifier).state = month - 1;
                    }
                  },
                ),
                Text(
                  '${_getMonthName(month)} $year',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: () {
                    if (month == 12) {
                      ref.read(calendarMonthProvider.notifier).state = 1;
                      ref.read(calendarYearProvider.notifier).state = year + 1;
                    } else {
                      ref.read(calendarMonthProvider.notifier).state = month + 1;
                    }
                  },
                ),
              ],
            ),
          ),

          // Days List
          Expanded(
            child: calendarAsync.when(
              loading: () => const LoadingIndicator(message: 'Loading calendar...'),
              error: (err, stack) => ErrorRetryWidget(
                errorMessage: err.toString(),
                onRetry: () => ref.invalidate(calendarDataProvider),
              ),
              data: (data) {
                final List days = data['days'] ?? [];

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final String status = day['status'] ?? 'NONE';
                    final bool isToday = day['is_today'] == true;
                    final bool isPast = day['is_past'] == true;
                    final bool isWeekend = day['is_weekend'] == true;
                    final bool isPlanned = status == 'PLANNED' || status == 'CONFIRMED' || status == 'ATTENDED';

                    return Card(
                      color: isToday
                          ? AppColors.primary.withValues(alpha: 0.05)
                          : isWeekend
                              ? Colors.grey.shade50
                              : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isToday ? const BorderSide(color: AppColors.primary, width: 1.5) : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Date Column
                            Container(
                              width: 50,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isToday ? AppColors.primary : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    day['day_number'].toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isToday ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    day['day_name'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isToday ? Colors.white70 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Status Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      StatusBadge(status: status),
                                      if (isToday) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
                                          child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isWeekend)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text('Weekend', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ),
                                ],
                              ),
                            ),

                            // Action Button
                            if (!isPast && !isWeekend) ...[
                              ElevatedButton(
                                onPressed: () => _toggleSchedule(context, ref, day['date'], isPlanned),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPlanned ? AppColors.error : AppColors.secondary,
                                  minimumSize: const Size(90, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: Text(
                                  isPlanned ? 'Opt Out' : 'Opt In',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ] else ...[
                              const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }
}

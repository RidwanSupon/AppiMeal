import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/employee_repository.dart';

final myMealHistoryProvider = FutureProvider.autoDispose((ref) async {
  final repo = EmployeeRepository();
  final now = DateTime.now();
  final calendar = await repo.getCalendar(month: now.month, year: now.year);
  final summary = await repo.getEmployeeSummary();
  return {
    'calendar': calendar,
    'summary': summary,
  };
});

class PaymentLedgerScreen extends ConsumerWidget {
  const PaymentLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(myMealHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Meal History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myMealHistoryProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading meal history...'),
        error: (err, stack) => ErrorRetryWidget(
          errorMessage: err.toString(),
          onRetry: () => ref.invalidate(myMealHistoryProvider),
        ),
        data: (data) {
          final summary = data['summary'] ?? {};
          final calendar = data['calendar'] ?? {};
          final monthly = summary['monthly'] ?? {};
          final List days = (calendar['days'] as List?) ?? [];
          final mealsTaken = monthly['meals_taken'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company Sponsored Hero Card
                Card(
                  color: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'COMPANY SPONSORED MEALS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Fully Paid by Company',
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '✓ Appifly BD Limited sponsors 100% of all employee daily lunches.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Monthly Summary Overview Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This Month Meal Statistics',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn('Meals Taken', '$mealsTaken', AppColors.primary),
                            Container(width: 1, height: 40, color: Colors.grey.shade300),
                            _buildStatColumn('Status', 'Active', AppColors.success),
                            Container(width: 1, height: 40, color: Colors.grey.shade300),
                            _buildStatColumn('Company Paid', '100%', AppColors.accent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Meal History Logs
                Text(
                  'Daily Attendance Log',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                days.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('No meal activity recorded yet for this month.')),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: days.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final day = days[index];
                          final status = day['status'] ?? 'NONE';
                          final dateStr = day['date'] ?? '';
                          final isToday = day['is_today'] == true;
                          final isAttended = status == 'ATTENDED';

                          return Container(
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isToday ? AppColors.primary : Colors.grey.shade200,
                                width: isToday ? 1.5 : 1.0,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isAttended
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : Colors.grey.shade100,
                                  child: Icon(
                                    isAttended ? Icons.restaurant : Icons.calendar_today,
                                    size: 20,
                                    color: isAttended ? AppColors.success : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isToday ? AppColors.primary : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isAttended ? '✓ Attended & Company Paid' : (status == 'PLANNED' ? 'Scheduled for Lunch' : 'Not Scheduled'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isAttended ? AppColors.success : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(status: status),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

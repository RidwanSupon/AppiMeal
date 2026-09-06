import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/employee_avatar.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/presentation/auth_provider.dart';

final cateringDataProvider = FutureProvider.autoDispose((ref) async {
  final repo = AdminRepository();
  final response = await repo.getCateringSummary();
  return response;
});

class CateringDashboardScreen extends ConsumerStatefulWidget {
  const CateringDashboardScreen({super.key});

  @override
  ConsumerState<CateringDashboardScreen> createState() => _CateringDashboardScreenState();
}

class _CateringDashboardScreenState extends ConsumerState<CateringDashboardScreen> {
  Timer? _autoRefreshTimer;
  int _refreshIntervalSeconds = 15;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _autoRefreshTimer?.cancel();
    if (_refreshIntervalSeconds > 0) {
      _autoRefreshTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (_) {
        ref.invalidate(cateringDataProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cateringAsync = ref.watch(cateringDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF181818), // High contrast dark theme for kitchen terminal
      appBar: AppBar(
        backgroundColor: const Color(0xFF262626),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.soup_kitchen_rounded, color: AppColors.accent, size: 28),
            SizedBox(width: 10),
            Text('CATERING DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
          ],
        ),
        actions: [
          PopupMenuButton<int>(
            initialValue: _refreshIntervalSeconds,
            tooltip: 'Auto Refresh Interval',
            icon: const Icon(Icons.timer_outlined, color: Colors.white),
            onSelected: (seconds) {
              setState(() {
                _refreshIntervalSeconds = seconds;
              });
              _startTimer();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 15, child: Text('Auto Refresh: 15s')),
              const PopupMenuItem(value: 30, child: Text('Auto Refresh: 30s')),
              const PopupMenuItem(value: 0, child: Text('Auto Refresh: OFF')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.accent, size: 28),
            onPressed: () => ref.invalidate(cateringDataProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: cateringAsync.when(
        loading: () => const LoadingIndicator(message: 'Updating live meal statistics...'),
        error: (err, stack) => ErrorRetryWidget(
          errorMessage: err.toString(),
          onRetry: () => ref.invalidate(cateringDataProvider),
        ),
        data: (data) {
          final String dateStr = data['date'] ?? '';
          final expected = data['total_expected'] ?? 0;
          final attended = data['lunch_taken'] ?? 0;
          final pending = data['pending'] ?? 0;
          final cancelled = data['cancelled'] ?? 0;

          final totalMealsDelivered = data['total_meals_delivered'] ?? 0;
          final totalBill = (data['total_catering_bill'] as num?)?.toDouble() ?? 0.0;
          final companyPaid = (data['company_paid'] as num?)?.toDouble() ?? 0.0;
          final cateringDue = (data['catering_due'] as num?)?.toDouble() ?? 0.0;

          final List dailyHistory = data['daily_history'] ?? [];
          final List todayAttendees = (data['today_attendees'] as List?) ?? (data['employees'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Financial Summary Cards Grid (Meals, Bill, Paid, Due)
                Text(
                  'Catering Account & Billing Summary',
                  style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildSummaryCard(
                      'TOTAL MEALS DELIVERED',
                      '$totalMealsDelivered Meals',
                      Icons.restaurant_menu_rounded,
                      AppColors.primary,
                    ),
                    _buildSummaryCard(
                      'TOTAL CATERING BILL',
                      DateFormatter.formatCurrency(totalBill),
                      Icons.receipt_long_rounded,
                      AppColors.accent,
                    ),
                    _buildSummaryCard(
                      'COMPANY PAID AMOUNT',
                      DateFormatter.formatCurrency(companyPaid),
                      Icons.check_circle_rounded,
                      AppColors.success,
                    ),
                    _buildSummaryCard(
                      'OUTSTANDING DUE',
                      DateFormatter.formatCurrency(cateringDue),
                      Icons.account_balance_wallet_rounded,
                      cateringDue > 0 ? AppColors.error : AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Today's Distribution Numbers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TODAY'S MEAL COUNTS",
                      style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accent),
                      ),
                      child: Text(
                        dateStr,
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildGiantCounterCard('EXPECTED TODAY', '$expected', Icons.group_rounded, Colors.blue)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildGiantCounterCard('SERVED TODAY', '$attended', Icons.check_circle_rounded, AppColors.success)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildGiantCounterCard('PENDING TODAY', '$pending', Icons.hourglass_top_rounded, AppColors.warning)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildGiantCounterCard('CANCELLED TODAY', '$cancelled', Icons.cancel_rounded, AppColors.error)),
                  ],
                ),
                const SizedBox(height: 24),

                // Today's Attendees & Meal List Section
                Text(
                  "TODAY'S ATTENDEES & LUNCH LIST (${todayAttendees.length})",
                  style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
                ),
                const SizedBox(height: 10),
                todayAttendees.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.grey),
                            SizedBox(width: 12),
                            Text('No attendee records found for today.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: todayAttendees.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final item = todayAttendees[idx];
                          final String name = item['full_name'] ?? 'Employee';
                          final String empId = item['employee_id'] ?? '';
                          final String dept = item['department'] ?? '';
                          final String status = item['status'] ?? (item['is_attended'] == true ? 'ATTENDED' : 'PENDING');
                          final String? time = item['attendance_time'];
                          final String? avatarUrl = item['avatar_url'];

                          Color statusColor = AppColors.warning;
                          if (status == 'ATTENDED') {
                            statusColor = AppColors.success;
                          } else if (status == 'CANCELLED') {
                            statusColor = AppColors.error;
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF262626),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                EmployeeAvatar(
                                  name: name,
                                  avatarUrl: avatarUrl,
                                  radius: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text('$empId • $dept', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(
                                    status == 'ATTENDED' && time != null ? 'SERVED $time' : status,
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 28),

                // Daily Meal Delivery History List (Date & Meal Counts Only - No Names)
                Text(
                  'Daily Meal Delivery History',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chronological record of daily meals served and daily billing amounts (Numbers Only)',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 12),

                dailyHistory.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Text('No delivery records available yet.', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dailyHistory.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = dailyHistory[index];
                          final date = item['date'] ?? '';
                          final dayName = item['day_name'] ?? date;
                          final delivered = item['meals_delivered'] ?? 0;
                          final scheduled = item['meals_scheduled'] ?? 0;
                          final double cost = (item['daily_cost'] as num?)?.toDouble() ?? 0.0;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF262626),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.restaurant_rounded, color: AppColors.accent, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dayName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Delivered: $delivered Meals  •  Scheduled: $scheduled',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$delivered Meals',
                                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormatter.formatCurrency(cost),
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGiantCounterCard(String label, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

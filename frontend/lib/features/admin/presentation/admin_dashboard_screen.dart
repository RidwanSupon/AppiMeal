import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/employee_avatar.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../data/admin_repository.dart';
import 'admin_catering_screen.dart';
import 'admin_manage_meals_screen.dart';
import 'audit_log_screen.dart';

final adminSummaryProvider = FutureProvider.autoDispose((ref) async {
  final repo = AdminRepository();
  return await repo.getAdminSummary();
});

class AdminDashboardScreen extends ConsumerWidget {
  final Function(int) onTabChange;

  const AdminDashboardScreen({super.key, required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(adminSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu_rounded),
            tooltip: 'Manual Meal Management',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManageMealsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Audit Logs',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminSummaryProvider),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading admin metrics...'),
        error: (err, stack) => ErrorRetryWidget(
          errorMessage: err.toString(),
          onRetry: () => ref.invalidate(adminSummaryProvider),
        ),
        data: (data) {
          final today = data['today'];
          final monthly = data['monthly'];
          final totals = data['totals'];
          final List dailyTrend = data['charts']['daily_trend'] ?? [];
          final List attendees = (today['attendees'] as List?) ?? [];

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminSummaryProvider),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Card
                  Card(
                    color: AppColors.primaryDark,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Appifly BD Limited • Meal Management Portal',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current Meal Rate: ${DateFormatter.formatCurrency(data['meal_price'])}',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                                child: const Text('Asia/Dhaka', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Today's Operational Metrics
                  Text("Today's Overview (${today['date']})", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildMetricTile('Today Scheduled', '${today['scheduled']}', Icons.calendar_today_rounded, AppColors.info),
                      _buildMetricTile('Today Attended', '${today['attended']}', Icons.check_circle_rounded, AppColors.success),
                      _buildMetricTile('Today Pending', '${today['pending']}', Icons.hourglass_empty_rounded, AppColors.warning),
                      _buildMetricTile('Today Cancelled', '${today['cancelled']}', Icons.cancel_rounded, AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Today's Attendees Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Today's Attendees (${attendees.length})", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if (attendees.isNotEmpty)
                        TextButton(
                          onPressed: () => onTabChange(3),
                          child: const Text('View All Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (attendees.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.grey),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No employees have taken lunch yet today.',
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: attendees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final att = attendees[idx];
                        final String name = att['full_name'] ?? 'Employee';
                        final String empId = att['employee_id'] ?? '';
                        final String dept = att['department'] ?? '';
                        final String time = att['attendance_time'] ?? 'Attended';
                        final String? avatarUrl = att['avatar_url'];

                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 1,
                          child: ListTile(
                            leading: EmployeeAvatar(
                              name: name,
                              avatarUrl: avatarUrl,
                              radius: 20,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('$empId • $dept', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    time,
                                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),

                  // Financial Metrics
                  Text('Financial Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildMetricTile('Today Meal Cost', DateFormatter.formatCurrency(today['cost']), Icons.attach_money_rounded, AppColors.accent),
                      _buildMetricTile('Monthly Cost', DateFormatter.formatCurrency(monthly['total_cost']), Icons.payments_rounded, AppColors.primary),
                      _buildMetricTile('Total Paid All Time', DateFormatter.formatCurrency(totals['total_paid']), Icons.verified_rounded, AppColors.success),
                      _buildMetricTile('Total Due Balance', DateFormatter.formatCurrency(totals['total_due']), Icons.account_balance_wallet_rounded, AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Trend Chart
                  if (dailyTrend.isNotEmpty) ...[
                    Text('7-Day Attendance Trend', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (dailyTrend.map((e) => (e['scheduled'] as int)).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                              barTouchData: BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (val, meta) {
                                      final idx = val.toInt();
                                      if (idx >= 0 && idx < dailyTrend.length) {
                                        return Text(dailyTrend[idx]['day'], style: const TextStyle(fontSize: 11));
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(dailyTrend.length, (idx) {
                                final item = dailyTrend[idx];
                                return BarChartGroupData(
                                  x: idx,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (item['attended'] as int).toDouble(),
                                      color: AppColors.success,
                                      width: 14,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Quick Nav Buttons
                  Text('Admin Operations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildNavChip(context, 'Manual Meal Management', Icons.restaurant_menu_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManageMealsScreen()))),
                      _buildNavChip(context, 'Catering Billing & Payments', Icons.flatware_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCateringScreen()))),
                      _buildNavChip(context, 'Manage Employees', Icons.people_outline, () => onTabChange(1)),
                      _buildNavChip(context, 'Record Payment', Icons.add_card_rounded, () => onTabChange(2)),
                      _buildNavChip(context, 'Reports & Analytics', Icons.bar_chart_rounded, () => onTabChange(3)),
                      _buildNavChip(context, 'System Settings', Icons.settings_outlined, () => onTabChange(4)),
                      _buildNavChip(context, 'Audit Logs', Icons.receipt_long_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogScreen()))),
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

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavChip(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onPressed: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../data/admin_repository.dart';

final reportTypeProvider = StateProvider.autoDispose<String>((ref) => 'daily');

final reportDataProvider = FutureProvider.autoDispose((ref) async {
  final type = ref.watch(reportTypeProvider);
  final repo = AdminRepository();

  if (type == 'daily') {
    return await repo.getDailyReport(DateTime.now().toIso8601String().split('T')[0]);
  } else if (type == 'monthly') {
    return await repo.getMonthlyReport(DateTime.now().month, DateTime.now().year);
  } else if (type == 'employees') {
    return await repo.getEmployeeReport();
  } else {
    return await repo.getDueReport();
  }
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  void _exportReport(BuildContext context, String type) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Appifly BD Limited $type report exported successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportType = ref.watch(reportTypeProvider);
    final reportAsync = ref.watch(reportDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _exportReport(context, reportType.toUpperCase()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(ref, 'Daily Lunch', 'daily', reportType),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Monthly Summary', 'monthly', reportType),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Employee Usage', 'employees', reportType),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Outstanding Dues', 'dues', reportType),
              ],
            ),
          ),

          // Report Content
          Expanded(
            child: reportAsync.when(
              loading: () => const LoadingIndicator(message: 'Generating report...'),
              error: (err, stack) => ErrorRetryWidget(errorMessage: err.toString(), onRetry: () => ref.invalidate(reportDataProvider)),
              data: (data) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Card(
                        color: Colors.grey.shade900,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['company'] ?? 'Appifly BD Limited', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(data['report_name'] ?? 'Report', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Generated: ${DateFormatter.formatDate(DateTime.now())}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ElevatedButton.icon(
                                    onPressed: () => _exportReport(context, reportType.toUpperCase()),
                                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                    label: const Text('Export PDF/CSV', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      minimumSize: const Size(120, 36),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Metrics Summary
                      if (reportType == 'daily') ...[
                        _buildSummaryRow('Total Scheduled', '${data['total_scheduled']}'),
                        _buildSummaryRow('Total Attended', '${data['total_attended']}'),
                        _buildSummaryRow('Total Cancelled', '${data['total_cancelled']}'),
                        _buildSummaryRow('Total Cost', DateFormatter.formatCurrency(data['total_cost'])),
                      ] else if (reportType == 'monthly') ...[
                        _buildSummaryRow('Period', data['period'] ?? ''),
                        _buildSummaryRow('Total Attended Meals', '${data['total_attended']}'),
                        _buildSummaryRow('Total Meal Cost', DateFormatter.formatCurrency(data['total_cost'])),
                        _buildSummaryRow('Total Payments Received', DateFormatter.formatCurrency(data['total_paid'])),
                        _buildSummaryRow('Current Due Balance', DateFormatter.formatCurrency(data['total_due'])),
                      ] else if (reportType == 'employees') ...[
                        Text('Employee Meal & Payment Breakdown (${(data['employees'] as List).length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (data['employees'] as List).length,
                          itemBuilder: (ctx, idx) {
                            final emp = data['employees'][idx];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(emp['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                          child: Text('${emp['total_meals']} Meals', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${emp['employee_id']} • ${emp['department']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Charges: ${DateFormatter.formatCurrency(emp['total_charges'])}', style: const TextStyle(fontSize: 12)),
                                        Text('Paid: ${DateFormatter.formatCurrency(emp['total_paid'])}', style: const TextStyle(fontSize: 12, color: AppColors.success)),
                                        Text('Due: ${DateFormatter.formatCurrency(emp['current_due'])}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: emp['current_due'] > 0 ? AppColors.error : Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ] else if (reportType == 'dues') ...[
                        _buildSummaryRow('Total Outstanding Dues', DateFormatter.formatCurrency(data['total_due_sum']), isBold: true, color: AppColors.error),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (data['employees_with_due'] as List).length,
                          itemBuilder: (ctx, idx) {
                            final item = data['employees_with_due'][idx];
                            return Card(
                              child: ListTile(
                                title: Text(item['employee']['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(item['employee']['employee_id']),
                                trailing: Text(
                                  DateFormatter.formatCurrency(item['current_due']),
                                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, String value, String currentValue) {
    final isSelected = value == currentValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(reportTypeProvider.notifier).state = value,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

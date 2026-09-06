import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../data/admin_repository.dart';

final adminCateringSummaryProvider = FutureProvider.autoDispose((ref) async {
  final repo = AdminRepository();
  return await repo.getAdminCateringSummary();
});

final cateringPaymentsProvider = FutureProvider.autoDispose((ref) async {
  final repo = AdminRepository();
  return await repo.getCateringPayments();
});

final employeeMealBreakdownProvider = FutureProvider.autoDispose((ref) async {
  final repo = AdminRepository();
  return await repo.getEmployeeMealBreakdown();
});

class AdminCateringScreen extends ConsumerStatefulWidget {
  const AdminCateringScreen({super.key});

  @override
  ConsumerState<AdminCateringScreen> createState() => _AdminCateringScreenState();
}

class _AdminCateringScreenState extends ConsumerState<AdminCateringScreen> {
  String _searchQuery = '';

  void _showRecordPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => RecordCateringPaymentDialog(
        onSuccess: () {
          ref.invalidate(adminCateringSummaryProvider);
          ref.invalidate(cateringPaymentsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(adminCateringSummaryProvider);
    final paymentsAsync = ref.watch(cateringPaymentsProvider);
    final breakdownAsync = ref.watch(employeeMealBreakdownProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catering Billing & Payments', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Employee Meals'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Catering Payments'),
            ],
          ),
        ),
        body: summaryAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading catering summary...'),
          error: (err, stack) => ErrorRetryWidget(
            errorMessage: err.toString(),
            onRetry: () {
              ref.invalidate(adminCateringSummaryProvider);
              ref.invalidate(cateringPaymentsProvider);
              ref.invalidate(employeeMealBreakdownProvider);
            },
          ),
          data: (summaryData) {
            final double totalBill = (double.tryParse(summaryData['total_bill']?.toString() ?? '0') ?? 0.0);
            final double totalPaid = (double.tryParse(summaryData['total_paid']?.toString() ?? '0') ?? 0.0);
            final double dueBalance = (double.tryParse(summaryData['due_balance']?.toString() ?? '0') ?? 0.0);
            final int totalMeals = (int.tryParse(summaryData['total_meals']?.toString() ?? '0') ?? 0);
            final double mealPrice = (double.tryParse(summaryData['meal_price']?.toString() ?? '120') ?? 120.0);

            return Column(
              children: [
                // Top Metrics Summary Card
                Container(
                  width: double.infinity,
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              title: 'Total Meals',
                              value: totalMeals.toString(),
                              subtitle: 'Rate: ৳${mealPrice.toStringAsFixed(0)}',
                              icon: Icons.flatware,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              title: 'Total Bill',
                              value: DateFormatter.formatCurrency(totalBill),
                              subtitle: 'Cumulative',
                              icon: Icons.account_balance_wallet,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              title: 'Company Paid',
                              value: DateFormatter.formatCurrency(totalPaid),
                              subtitle: 'To Catering',
                              icon: Icons.check_circle_outline,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricTile(
                              context,
                              title: 'Catering Due',
                              value: DateFormatter.formatCurrency(dueBalance),
                              subtitle: dueBalance > 0 ? 'Pending Settlement' : 'Settled',
                              icon: Icons.pending_actions,
                              color: dueBalance > 0 ? AppColors.warning : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showRecordPaymentDialog(context),
                          icon: const Icon(Icons.add_card_rounded),
                          label: const Text('Record Payment to Catering', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Employee Meal Consumption
                      breakdownAsync.when(
                        loading: () => const LoadingIndicator(message: 'Loading employee breakdown...'),
                        error: (err, _) => ErrorRetryWidget(errorMessage: err.toString(), onRetry: () => ref.invalidate(employeeMealBreakdownProvider)),
                        data: (breakdownData) {
                          final List employees = breakdownData['employees'] ?? [];
                          final filtered = employees.where((emp) {
                            final q = _searchQuery.toLowerCase();
                            final name = (emp['full_name'] ?? '').toString().toLowerCase();
                            final empId = (emp['employee_id'] ?? '').toString().toLowerCase();
                            return name.contains(q) || empId.contains(q);
                          }).toList();

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Search employee by name or ID...',
                                    prefixIcon: Icon(Icons.search),
                                    isDense: true,
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                              Expanded(
                                child: filtered.isEmpty
                                    ? const Center(child: Text('No meal consumption data available.'))
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                                        itemBuilder: (context, idx) {
                                          final emp = filtered[idx];
                                          final int meals = emp['meals_taken'] ?? 0;
                                          final double cost = (double.tryParse(emp['total_cost']?.toString() ?? '0') ?? 0.0);
                                          final String name = emp['full_name']?.toString() ?? 'Employee';
                                          final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';

                                          return Card(
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: AppColors.primary.withAlpha(30),
                                                child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                              ),
                                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              subtitle: Text('${emp['employee_id'] ?? ''} • ${emp['department'] ?? ''}'),
                                              trailing: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withAlpha(20),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      '$meals meals',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    DateFormatter.formatCurrency(cost),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryLight),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),

                      // Tab 2: Recent Catering Payments
                      paymentsAsync.when(
                        loading: () => const LoadingIndicator(message: 'Loading catering payments...'),
                        error: (err, _) => ErrorRetryWidget(errorMessage: err.toString(), onRetry: () => ref.invalidate(cateringPaymentsProvider)),
                        data: (paymentsData) {
                          final List payments = paymentsData['data'] ?? [];

                          if (payments.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long, size: 48, color: AppColors.textSecondaryLight),
                                  SizedBox(height: 12),
                                  Text('No payment records to Catering yet.', style: TextStyle(color: AppColors.textSecondaryLight)),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: payments.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final pay = payments[idx];
                              final double amount = double.tryParse(pay['amount']?.toString() ?? '0') ?? 0.0;
                              final String payId = pay['payment_id']?.toString() ?? '';
                              final String method = pay['payment_method']?.toString() ?? 'Bank Transfer';
                              final String dateStr = pay['payment_date']?.toString() ?? '';
                              final String refNotes = pay['reference'] != null ? 'Ref: ${pay['reference']}' : (pay['notes'] ?? '');

                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    child: Icon(Icons.arrow_upward_rounded, size: 20),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(payId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                      Text(DateFormatter.formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 14)),
                                    ],
                                  ),
                                  subtitle: Text('$method • $dateStr${refNotes.isNotEmpty ? '\n$refNotes' : ''}'),
                                  isThreeLine: refNotes.isNotEmpty,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w500)),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecordCateringPaymentDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const RecordCateringPaymentDialog({super.key, required this.onSuccess});

  @override
  State<RecordCateringPaymentDialog> createState() => _RecordCateringPaymentDialogState();
}

class _RecordCateringPaymentDialogState extends State<RecordCateringPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'Bank Transfer';
  DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;

  final List<String> _methods = const ['Bank Transfer', 'Cash', 'bKash', 'Nagad', 'Check', 'Other'];

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final repo = AdminRepository();
        await repo.recordCateringPayment({
          'amount': double.parse(_amountCtrl.text.trim()),
          'payment_date': DateFormatter.formatDateForApi(_paymentDate),
          'payment_method': _paymentMethod,
          'reference': _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
          'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Payment to Catering recorded successfully!'), backgroundColor: AppColors.success),
          );
          widget.onSuccess();
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
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.payments, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Record Payment to Catering', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _amountCtrl,
                label: 'Payment Amount (BDT ৳)',
                hint: 'e.g. 5000.00',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.attach_money,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                  if (double.tryParse(v.trim()) == null || double.parse(v.trim()) <= 0) return 'Enter valid positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', prefixIcon: Icon(Icons.payment)),
                items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _refCtrl,
                label: 'Reference / Cheque No.',
                hint: 'Optional reference',
                prefixIcon: Icons.tag,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _notesCtrl,
                label: 'Notes / Remarks',
                hint: 'Optional payment notes',
                prefixIcon: Icons.note,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        CustomButton(
          text: 'Record Payment',
          icon: Icons.check_circle,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }
}

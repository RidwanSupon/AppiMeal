import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../data/admin_repository.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key});

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _selectedMethod = 'bKash';
  bool _isLoading = false;
  
  Map<String, dynamic>? _cateringSummary;
  bool _isLoadingSummary = false;

  List _recentPayments = [];
  bool _isLoadingPayments = false;

  @override
  void initState() {
    super.initState();
    _loadSummaryAndPayments();
  }

  void _loadSummaryAndPayments() {
    _loadCateringSummary();
    _loadRecentPayments();
  }

  void _loadCateringSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final repo = AdminRepository();
      final res = await repo.getAdminCateringSummary();
      if (mounted) {
        setState(() {
          _cateringSummary = res;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  void _loadRecentPayments() async {
    setState(() => _isLoadingPayments = true);
    try {
      final repo = AdminRepository();
      final data = await repo.getCateringPayments();
      if (mounted) {
        setState(() {
          if (data['data'] != null && data['data'] is List) {
            _recentPayments = List.from(data['data']);
          } else {
            _recentPayments = [];
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingPayments = false);
    }
  }

  void _submitPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final repo = AdminRepository();
        final res = await repo.recordCateringPayment({
          'amount': double.parse(_amountCtrl.text.trim()),
          'payment_date': DateTime.now().toIso8601String().split('T')[0],
          'payment_method': _selectedMethod,
          'reference': _refCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Catering payment recorded successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          _amountCtrl.clear();
          _refCtrl.clear();
          _notesCtrl.clear();
          _loadSummaryAndPayments();
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
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final due = _cateringSummary != null ? (num.tryParse(_cateringSummary!['due_balance'].toString()) ?? 0.0) : 0.0;
    final totalBill = _cateringSummary != null ? (num.tryParse(_cateringSummary!['total_bill'].toString()) ?? 0.0) : 0.0;
    final totalPaid = _cateringSummary != null ? (num.tryParse(_cateringSummary!['total_paid'].toString()) ?? 0.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catering Payment Record', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSummaryAndPayments,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Catering Summary & Total Due Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catering Due Summary',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_isLoadingSummary)
                        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                      else
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: due > 0 ? AppColors.error.withValues(alpha: 0.08) : AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: due > 0 ? AppColors.error.withValues(alpha: 0.3) : AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        due > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                        color: due > 0 ? AppColors.error : AppColors.success,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Company Due to Catering',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: due > 0 ? AppColors.error : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    DateFormatter.formatCurrency(due),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: due > 0 ? AppColors.error : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Total Bill: ${DateFormatter.formatCurrency(totalBill)} • Paid: ${DateFormatter.formatCurrency(totalPaid)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  if (due > 0)
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _amountCtrl.text = due.toStringAsFixed(due.truncateToDouble() == due ? 0 : 2);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Pay Full Due',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      CustomTextField(
                        controller: _amountCtrl,
                        label: 'Payment Amount (৳)',
                        hint: 'e.g. 1000',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.payments_outlined,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Enter payment amount';
                          final num? parsed = num.tryParse(val);
                          if (parsed == null || parsed <= 0) return 'Amount must be greater than 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMethod,
                        decoration: const InputDecoration(labelText: 'Method'),
                        items: ['bKash', 'Bank Transfer', 'Cash', 'Nagad', 'Check', 'Other'].map((m) {
                          return DropdownMenuItem<String>(value: m, child: Text(m));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedMethod = val!),
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _refCtrl,
                        label: 'Transaction Reference',
                        hint: 'e.g. CAT-TXN-987654',
                        prefixIcon: Icons.receipt_long_outlined,
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _notesCtrl,
                        label: 'Notes / Remarks',
                        hint: 'Optional payment notes...',
                        prefixIcon: Icons.note_outlined,
                      ),
                      const SizedBox(height: 24),

                      CustomButton(
                        text: 'Record Catering Payment',
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: _isLoading,
                        backgroundColor: AppColors.success,
                        onPressed: _submitPayment,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Payments History Section
              Text(
                'Recent Catering Payments',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (_isLoadingPayments)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_recentPayments.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No catering payments recorded yet.')))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentPayments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final pay = _recentPayments[idx];
                    final recorder = pay['recorder'] ?? {};
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.success,
                          child: Icon(Icons.flatware_rounded, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          'Payment ID: ${pay['payment_id']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Method: ${pay['payment_method']} • Ref: ${pay['reference'] ?? 'N/A'}\nDate: ${pay['payment_date']}' +
                              (recorder['full_name'] != null ? ' • Recorded by: ${recorder['full_name']}' : ''),
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          DateFormatter.formatCurrency(num.tryParse(pay['amount'].toString()) ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

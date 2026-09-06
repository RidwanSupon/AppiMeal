import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/employee_avatar.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../data/admin_repository.dart';
import 'admin_dashboard_screen.dart';

final adminManageMealsProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, date) async {
  final repo = AdminRepository();
  return await repo.getAdminManageList(date: date);
});

class AdminManageMealsScreen extends ConsumerStatefulWidget {
  const AdminManageMealsScreen({super.key});

  @override
  ConsumerState<AdminManageMealsScreen> createState() => _AdminManageMealsScreenState();
}

class _AdminManageMealsScreenState extends ConsumerState<AdminManageMealsScreen> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int? _processingEmpId;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2027, 12, 31),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateMealStatus(int employeeId, String newStatus, String employeeName) async {
    setState(() => _processingEmpId = employeeId);
    try {
      final repo = AdminRepository();
      final res = await repo.manualManageMeal({
        'employee_id': employeeId,
        'lunch_date': _dateStr,
        'status': newStatus,
        'notes': 'Manual admin action',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Meal status updated successfully for $employeeName.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        ref.invalidate(adminManageMealsProvider(_dateStr));
        ref.invalidate(adminSummaryProvider);
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
        setState(() => _processingEmpId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(adminManageMealsProvider(_dateStr));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Meal Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminManageMealsProvider(_dateStr)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector Header
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  onPressed: () => _changeDate(-1),
                ),
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEE, MMM dd, yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (_selectedDate.year == DateTime.now().year &&
                            _selectedDate.month == DateTime.now().month &&
                            _selectedDate.day == DateTime.now().day)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Today', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Content
          Expanded(
            child: listAsync.when(
              loading: () => const LoadingIndicator(message: 'Fetching meal records...'),
              error: (err, stack) => ErrorRetryWidget(
                errorMessage: err.toString(),
                onRetry: () => ref.invalidate(adminManageMealsProvider(_dateStr)),
              ),
              data: (data) {
                final List employees = data['employees'] ?? [];
                final int scheduled = data['total_scheduled'] ?? 0;
                final int attended = data['total_attended'] ?? 0;
                final int pending = data['total_pending'] ?? 0;
                final int cancelled = data['total_cancelled'] ?? 0;

                final filteredEmployees = employees.where((emp) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  final name = (emp['full_name'] ?? '').toString().toLowerCase();
                  final empCode = (emp['employee_id'] ?? '').toString().toLowerCase();
                  final dept = (emp['department'] ?? '').toString().toLowerCase();
                  return name.contains(q) || empCode.contains(q) || dept.contains(q);
                }).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Chips Bar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCountChip('Scheduled', scheduled, AppColors.info),
                            const SizedBox(width: 8),
                            _buildCountChip('Attended', attended, AppColors.success),
                            const SizedBox(width: 8),
                            _buildCountChip('Pending', pending, AppColors.warning),
                            const SizedBox(width: 8),
                            _buildCountChip('Cancelled', cancelled, AppColors.error),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search Input
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search employee by name, ID or dept...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                      const SizedBox(height: 16),

                      // Employees List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Employees (${filteredEmployees.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text('Tap status to change', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (filteredEmployees.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text('No employees found matching criteria.', style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredEmployees.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final emp = filteredEmployees[idx];
                            final int id = emp['id'];
                            final String name = emp['full_name'] ?? 'Employee';
                            final String empCode = emp['employee_id'] ?? '';
                            final String dept = emp['department'] ?? '';
                            final String status = emp['status'] ?? 'NOT_SCHEDULED';
                            final String? time = emp['attendance_time'];
                            final String? avatarUrl = emp['avatar_url'];
                            final bool isProcessing = _processingEmpId == id;

                            return Card(
                              margin: EdgeInsets.zero,
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: EmployeeAvatar(name: name, avatarUrl: avatarUrl, radius: 20),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('$empCode • $dept${time != null ? ' • $time' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                trailing: isProcessing
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                    : PopupMenuButton<String>(
                                        onSelected: (newStatus) => _updateMealStatus(id, newStatus, name),
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'ATTENDED',
                                            child: Row(
                                              children: const [
                                                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                                                SizedBox(width: 8),
                                                Text('Mark Attended (Checked in)'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'PLANNED',
                                            child: Row(
                                              children: const [
                                                Icon(Icons.calendar_today_rounded, color: AppColors.info, size: 20),
                                                SizedBox(width: 8),
                                                Text('Schedule Meal (Planned)'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'CANCELLED',
                                            child: Row(
                                              children: const [
                                                Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                                                SizedBox(width: 8),
                                                Text('Cancel Meal'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'NOT_SCHEDULED',
                                            child: Row(
                                              children: const [
                                                Icon(Icons.remove_circle_outline_rounded, color: Colors.grey, size: 20),
                                                SizedBox(width: 8),
                                                Text('Remove Schedule'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        child: _buildStatusBadge(status),
                                      ),
                              ),
                            );
                          },
                        ),
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

  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'ATTENDED':
        bg = AppColors.success.withOpacity(0.15);
        fg = AppColors.success;
        icon = Icons.check_circle_rounded;
        label = 'Attended';
        break;
      case 'PLANNED':
        bg = AppColors.info.withOpacity(0.15);
        fg = AppColors.info;
        icon = Icons.calendar_today_rounded;
        label = 'Scheduled';
        break;
      case 'CANCELLED':
        bg = AppColors.error.withOpacity(0.15);
        fg = AppColors.error;
        icon = Icons.cancel_rounded;
        label = 'Cancelled';
        break;
      default:
        bg = Colors.grey.withOpacity(0.15);
        fg = Colors.grey.shade700;
        icon = Icons.remove_circle_outline_rounded;
        label = 'No Meal';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 16, color: fg),
        ],
      ),
    );
  }
}

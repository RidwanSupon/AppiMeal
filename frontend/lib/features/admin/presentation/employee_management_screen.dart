import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/employee_avatar.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/admin_repository.dart';

final employeeSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final employeeListProvider = FutureProvider.autoDispose((ref) async {
  final search = ref.watch(employeeSearchQueryProvider);
  final repo = AdminRepository();
  return await repo.getEmployees(search: search);
});

class EmployeeManagementScreen extends ConsumerWidget {
  const EmployeeManagementScreen({super.key});

  void _showAddEmployeeDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final empIdCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'Software Engineering');
    final desigCtrl = TextEditingController(text: 'Software Engineer');
    final passwordCtrl = TextEditingController(text: 'Password123!');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Employee'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(controller: nameCtrl, label: 'Full Name', hint: 'e.g. Tanvir Ahmed', validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                CustomTextField(controller: empIdCtrl, label: 'Employee ID', hint: 'e.g. EMP-006', validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                CustomTextField(controller: emailCtrl, label: 'Email', hint: 'tanvir@appiflybd.com', keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                CustomTextField(controller: phoneCtrl, label: 'Phone', hint: '+8801711000000'),
                const SizedBox(height: 12),
                CustomTextField(controller: deptCtrl, label: 'Department', hint: 'Software Engineering'),
                const SizedBox(height: 12),
                CustomTextField(controller: desigCtrl, label: 'Designation', hint: 'Senior Engineer'),
                const SizedBox(height: 12),
                CustomTextField(controller: passwordCtrl, label: 'Password', hint: 'Minimum 8 characters', validator: (v) => (v == null || v.length < 8) ? 'Min 8 chars' : null),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final repo = AdminRepository();
                  await repo.createEmployee({
                    'full_name': nameCtrl.text.trim(),
                    'employee_id': empIdCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'department': deptCtrl.text.trim(),
                    'designation': desigCtrl.text.trim(),
                    'password': passwordCtrl.text,
                    'role': 'employee',
                  });

                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(const SnackBar(content: Text('Employee added successfully.'), backgroundColor: AppColors.success));
                  ref.invalidate(employeeListProvider);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  void _showEditEmployeeDialog(BuildContext context, WidgetRef ref, Map emp) {
    final nameCtrl = TextEditingController(text: emp['full_name']);
    final phoneCtrl = TextEditingController(text: emp['phone'] ?? '');
    final deptCtrl = TextEditingController(text: emp['department']);
    final desigCtrl = TextEditingController(text: emp['designation']);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Employee (${emp['employee_id']})'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(controller: nameCtrl, label: 'Full Name', validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                CustomTextField(controller: phoneCtrl, label: 'Phone Number'),
                const SizedBox(height: 12),
                CustomTextField(controller: deptCtrl, label: 'Department'),
                const SizedBox(height: 12),
                CustomTextField(controller: desigCtrl, label: 'Designation'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final repo = AdminRepository();
                  await repo.updateEmployee(emp['id'], {
                    'full_name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'department': deptCtrl.text.trim(),
                    'designation': desigCtrl.text.trim(),
                  });

                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(const SnackBar(content: Text('Employee updated successfully.'), backgroundColor: AppColors.success));
                  ref.invalidate(employeeListProvider);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, Map emp) {
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password for ${emp['full_name']}'),
        content: Form(
          key: formKey,
          child: CustomTextField(
            controller: passCtrl,
            label: 'New Password',
            hint: 'Min 8 characters',
            validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final repo = AdminRepository();
                  await repo.resetEmployeePassword(emp['id'], passCtrl.text);

                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(SnackBar(content: Text('Password reset for ${emp['full_name']}'), backgroundColor: AppColors.success));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(BuildContext context, WidgetRef ref, int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = AdminRepository();
      await repo.toggleEmployeeStatus(id);
      messenger.showSnackBar(const SnackBar(content: Text('Employee status updated.'), backgroundColor: AppColors.success));
      ref.invalidate(employeeListProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () => _showAddEmployeeDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, ID, or email...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) {
                ref.read(employeeSearchQueryProvider.notifier).state = val;
              },
            ),
          ),

          // List
          Expanded(
            child: employeesAsync.when(
              loading: () => const LoadingIndicator(message: 'Fetching employees...'),
              error: (err, stack) => ErrorRetryWidget(errorMessage: err.toString(), onRetry: () => ref.invalidate(employeeListProvider)),
              data: (data) {
                final List employees = data['data'] ?? [];

                if (employees.isEmpty) {
                  return const Center(child: Text('No employees found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: employees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    final ledger = emp['ledger'];
                    final due = (ledger != null && ledger['current_due'] != null) ? (double.tryParse(ledger['current_due'].toString()) ?? 0.0) : 0.0;
                    final name = emp['full_name']?.toString() ?? 'Employee';

                    return Card(
                      child: ListTile(
                        leading: EmployeeAvatar(
                          avatarUrl: emp['avatar_url'],
                          name: name,
                          radius: 20,
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            StatusBadge(status: emp['status']?.toString() ?? 'active'),
                          ],
                        ),
                        subtitle: Text('${emp['employee_id'] ?? ''} • ${emp['department'] ?? ''}\nDue: ${DateFormatter.formatCurrency(due)}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showEditEmployeeDialog(context, ref, emp);
                            } else if (val == 'reset') {
                              _showResetPasswordDialog(context, emp);
                            } else if (val == 'status') {
                              _toggleStatus(context, ref, emp['id']);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit Details')])),
                            const PopupMenuItem(value: 'reset', child: Row(children: [Icon(Icons.lock_reset, size: 18), SizedBox(width: 8), Text('Reset Password')])),
                            PopupMenuItem(
                              value: 'status',
                              child: Row(
                                children: [
                                  Icon(emp['status'] == 'active' ? Icons.block : Icons.check_circle, size: 18, color: emp['status'] == 'active' ? AppColors.error : AppColors.success),
                                  const SizedBox(width: 8),
                                  Text(emp['status'] == 'active' ? 'Deactivate' : 'Activate'),
                                ],
                              ),
                            ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
    );
  }
}

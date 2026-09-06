import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';

final notificationsListProvider = FutureProvider.autoDispose((ref) async {
  final client = ApiClient();
  final response = await client.get('/notifications');
  return response.data['data'];
});

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: notificationsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading notifications...'),
        error: (err, stack) => ErrorRetryWidget(errorMessage: err.toString(), onRetry: () => ref.invalidate(notificationsListProvider)),
        data: (data) {
          final List list = data['data'] ?? [];

          if (list.isEmpty) {
            return const EmptyStateWidget(title: 'No Notifications', message: 'You are all caught up!');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final notif = list[idx];
              final isRead = notif['is_read'] == true;

              return Card(
                color: isRead ? null : Colors.blue.shade50,
                child: ListTile(
                  leading: Icon(
                    isRead ? Icons.notifications_none : Icons.notifications_active,
                    color: isRead ? Colors.grey : Colors.blue,
                  ),
                  title: Text(notif['title'], style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(notif['message']),
                  trailing: Text(notif['created_at']?.split('T')[0] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';

class FeedbackHistoryScreen extends ConsumerWidget {
  const FeedbackHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(myFeedbackProvider);
    final busesAsync = ref.watch(allBusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Feedback'),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/submit-feedback'),
        icon: const Icon(Icons.add),
        label: const Text('Submit'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myFeedbackProvider.future),
        child: feedbackAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'No feedback submitted yet.\nTap "Submit" to report an issue.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            final buses = busesAsync.valueOrNull ?? const [];
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final f = rows[i];
                final busName = buses
                    .where((b) => b.id == f.busId)
                    .map((b) => b.plateNumber)
                    .firstOrNull;
                return _FeedbackCard(feedback: f, busPlate: busName);
              },
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final BusFeedback feedback;
  final String? busPlate;

  const _FeedbackCard({required this.feedback, this.busPlate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(busPlate ?? feedback.busId,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                _StatusChip(status: feedback.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(feedback.description),
            if (feedback.screenshotUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  feedback.screenshotUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 60,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Text('Screenshot unavailable'),
                  ),
                ),
              ),
            ],
            if (feedback.adminResponse != null &&
                feedback.adminResponse!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin response',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 4),
                    Text(feedback.adminResponse!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              DateFormat('d MMM yyyy, HH:mm').format(feedback.timestamp.toLocal()),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final FeedbackStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      FeedbackStatus.newSubmission => ('New', Colors.blue),
      FeedbackStatus.inProgress => ('In progress', Colors.orange),
      FeedbackStatus.resolved => ('Resolved', Colors.green),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

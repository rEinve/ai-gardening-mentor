import 'package:flutter/material.dart';

import '../data/offline_garden_store.dart';
import '../models/garden_models.dart';

/// `/tasks/:taskId` — Renders instructions, ordered steps, rationale, duration,
/// approved source references, and append-only offline completion action.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.store,
    required this.canComplete,
  });

  final TaskModel task;
  final OfflineGardenStore store;
  final bool canComplete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final status = store.effectiveStatusFor(task);
        final isCompleted = status == EffectiveTaskStatus.completed;

        return Scaffold(
          appBar: AppBar(title: Text(task.cropName)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('${task.estimatedDurationMinutes} min')),
                  Chip(label: Text(status.name)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                task.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(task.instructions, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              Text('Steps', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...task.steps.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: cs.primaryContainer,
                            child: Text('${entry.key + 1}', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Card(
                color: cs.secondaryContainer.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Why this matters', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(task.rationale),
                    ],
                  ),
                ),
              ),
              if (task.sources.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Source Reference', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...task.sources.map(
                  (src) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(src.title),
                    subtitle: Text('${src.publisher} • ${src.canonicalUrl}'),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: (!canComplete || isCompleted)
                    ? null
                    : () => store.markTaskCompleted(task.taskId),
                icon: Icon(isCompleted ? Icons.check_circle : Icons.check),
                label: Text(
                  isCompleted
                      ? 'Completed (Saved Offline)'
                      : canComplete
                          ? 'Mark Completed'
                          : 'Future Task (Read-only)',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

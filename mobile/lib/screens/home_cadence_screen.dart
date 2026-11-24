import 'package:flutter/material.dart';

import '../data/offline_garden_store.dart';
import '../models/garden_models.dart';
import 'account_screen.dart';
import 'task_detail_screen.dart';

/// `/home` — Rolling 7-day care cadence with offline-first completion tracking.
/// Future dates are read-only per docs/app-_flow.md.
class HomeCadenceScreen extends StatefulWidget {
  const HomeCadenceScreen({super.key, required this.store});

  final OfflineGardenStore store;

  @override
  State<HomeCadenceScreen> createState() => _HomeCadenceScreenState();
}

class _HomeCadenceScreenState extends State<HomeCadenceScreen> {
  int _selectedDayOffset = 0;

  String _dateForOffset(int offset) {
    final dt = DateTime.now().add(Duration(days: offset));
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedDate = _dateForOffset(_selectedDayOffset);
    final isToday = _selectedDayOffset == 0;
    final tasks = widget.store.tasksForDate(selectedDate);
    final totalMinutes = tasks.fold<int>(0, (sum, t) => sum + t.estimatedDurationMinutes);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.activePlot?.regionName ?? 'Tanzania Garden'),
        actions: [
          if (widget.store.pendingSyncCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                avatar: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: Text('${widget.store.pendingSyncCount} pending'),
              ),
            ),
          IconButton(
            tooltip: 'My Account & Farm Contacts',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => AccountScreen(store: widget.store)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 7-day rolling calendar strip
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final selected = idx == _selectedDayOffset;
                final dt = DateTime.now().add(Duration(days: idx));
                return ChoiceChip(
                  label: Text(idx == 0 ? 'Today' : '${dt.day}/${dt.month}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedDayOffset = idx),
                );
              },
            ),
          ),

          // Routine summary banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isToday ? "Today's Micro-Habits" : 'Scheduled for $selectedDate (Read-only)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text('~$totalMinutes min', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // Task list
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.spa_outlined, size: 40, color: cs.primary),
                          const SizedBox(height: 12),
                          Text(
                            'No care tasks scheduled for this day. Enjoy your garden!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final status = widget.store.effectiveStatusFor(task);
                      final isCompleted = status == EffectiveTaskStatus.completed;

                      return Card(
                        child: ListTile(
                          leading: Checkbox(
                            value: isCompleted,
                            onChanged: (!isToday || isCompleted)
                                ? null
                                : (_) => widget.store.markTaskCompleted(task.taskId),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text('${task.cropName} • ${task.estimatedDurationMinutes} min'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TaskDetailScreen(
                                  task: task,
                                  store: widget.store,
                                  canComplete: isToday,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

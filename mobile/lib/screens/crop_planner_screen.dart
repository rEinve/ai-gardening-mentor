import 'package:flutter/material.dart';

import '../data/offline_garden_store.dart';
import '../models/agro_supplier_models.dart';
import '../models/crop_planner_models.dart';
import 'agro_supplier_sheet.dart';

enum _PlannerViewMode { month, week, batches }

/// `/planner` — Proactive Crop Planner with Monthly & Weekly Calendar views
/// plus Waterfall Batch & Succession Planting management.
class CropPlannerScreen extends StatefulWidget {
  const CropPlannerScreen({super.key, required this.store});

  final OfflineGardenStore store;

  @override
  State<CropPlannerScreen> createState() => _CropPlannerScreenState();
}

class _CropPlannerScreenState extends State<CropPlannerScreen> {
  _PlannerViewMode _viewMode = _PlannerViewMode.month;
  int _monthOffset = 0; // 0 = This Month, 1 = Next Month, etc.

  OfflineGardenStore get store => widget.store;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  DateTime _selectedMonthDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + _monthOffset, 1);
  }

  List<ScheduledMilestone> _allMilestonesSorted(List<ComputedBatchSchedule> schedules) {
    final all = schedules.expand((s) => s.milestones).toList();
    all.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return all;
  }

  Future<void> _openNewPlanSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _AddCropPlanSheet(store: store),
    );
  }

  Future<void> _openMilestoneActionSheet(
    BuildContext context,
    ScheduledMilestone milestone,
  ) async {
    final schedule = store.computedBatchSchedules.cast<ComputedBatchSchedule?>().firstWhere(
          (s) => s?.plan.batchId == milestone.batchId,
          orElse: () => null,
        );
    final isDone = schedule?.plan.completedMilestoneIds.contains(milestone.id) ?? false;
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(phaseLabel(milestone.phase)),
                  backgroundColor: cs.primaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  milestone.daysFromToday > 0
                      ? 'Due in ${milestone.daysFromToday} days (${milestone.scheduledDate})'
                      : milestone.daysFromToday == 0
                          ? 'Due today (${milestone.scheduledDate})'
                          : '${milestone.daysFromToday.abs()} days ago (${milestone.scheduledDate})',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${milestone.cropLabel}: ${milestone.title}',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(milestone.summary),
            if (milestone.conventionalInput != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended Input & Dosage',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(milestone.conventionalInput!),
                  ],
                ),
              ),
            ],
            if (milestone.prepReminder != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      milestone.prepReminder!,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (milestone.phase == WaterfallPhase.harvest) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    showAgroSupplierSheet(
                      context,
                      store: store,
                      initialCategory: FarmContactCategory.buyer,
                    );
                  },
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Call Saved Buyers / Clients'),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (milestone.conventionalInput != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    showAgroSupplierSheet(
                      context,
                      store: store,
                      recommendedInput: milestone.conventionalInput,
                      initialCategory: FarmContactCategory.supplier,
                    );
                  },
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Find Agro-Dealer & Check Price'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  store.toggleMilestoneCompleted(milestone.batchId, milestone.id);
                  Navigator.of(ctx).pop();
                },
                icon: Icon(isDone ? Icons.undo : Icons.check_circle_outline),
                label: Text(isDone ? 'Mark as Not Done Yet' : 'Mark Prepared / Completed'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickActualHarvestDate(
    BuildContext context,
    ComputedBatchSchedule schedule,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Log Actual Harvest Date',
    );
    if (picked != null) {
      store.logActualHarvestDate(schedule.plan.batchId, formatIsoDate(picked));
    }
  }

  Future<void> _confirmRemoveBatch(
    BuildContext context,
    ComputedBatchSchedule schedule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${schedule.batchDisplayLabel}?'),
        content: const Text('Remove this crop batch from your active plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.removeCropBatch(schedule.plan.batchId);
    }
  }

  Future<void> _shiftBatchDateDialog(
    BuildContext context,
    ComputedBatchSchedule schedule,
  ) async {
    final current = parseIsoDate(schedule.plan.anchorDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 1),
      lastDate: DateTime(current.year + 2),
      helpText: 'Set Actual Planting / Transplant Date',
    );
    if (picked == null || !context.mounted) return;
    final newIso = formatIsoDate(picked);
    final hasSuccession = schedule.plan.successionGroupId != null;

    if (!hasSuccession) {
      store.rescheduleBatch(schedule.plan.batchId, newIso, cascadeSuccession: false);
      return;
    }

    final cascade = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shift following succession batches?'),
        content: Text(
          'You moved ${schedule.batchDisplayLabel} to $newIso. '
          'Do you want later batches in this succession plan to shift automatically?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Only this batch'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cascade later batches'),
          ),
        ],
      ),
    );
    if (cascade != null) {
      store.rescheduleBatch(schedule.plan.batchId, newIso, cascadeSuccession: cascade);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schedules = store.computedBatchSchedules;
    final prepAlerts = store.upcomingPrepAlerts;
    final allMilestones = _allMilestonesSorted(schedules);
    final selectedMonth = _selectedMonthDate();
    final selectedMonthPrefix =
        '${selectedMonth.year.toString().padLeft(4, '0')}-${selectedMonth.month.toString().padLeft(2, '0')}';
    final monthMilestones = allMilestones
        .where((m) => m.scheduledDate.startsWith(selectedMonthPrefix))
        .toList();
    final weekMilestones = allMilestones
        .where((m) => m.daysFromToday >= 0 && m.daysFromToday <= 7)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Planner'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () => _openNewPlanSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Plan Crop'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SegmentedButton<_PlannerViewMode>(
            segments: const [
              ButtonSegment(
                value: _PlannerViewMode.month,
                icon: Icon(Icons.calendar_month_outlined),
                label: Text('Month'),
              ),
              ButtonSegment(
                value: _PlannerViewMode.week,
                icon: Icon(Icons.view_week_outlined),
                label: Text('Week'),
              ),
              ButtonSegment(
                value: _PlannerViewMode.batches,
                icon: Icon(Icons.layers_outlined),
                label: Text('Batches'),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (sel) => setState(() => _viewMode = sel.first),
          ),
          const SizedBox(height: 12),

          if (_viewMode == _PlannerViewMode.month) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => _monthOffset--),
                    ),
                    Column(
                      children: [
                        Text(
                          '${_monthNames[selectedMonth.month - 1]} ${selectedMonth.year}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _monthOffset == 0
                              ? 'This Month'
                              : _monthOffset == 1
                                  ? 'Next Month'
                                  : _monthOffset == -1
                                      ? 'Last Month'
                                      : '${_monthOffset > 0 ? '+' : ''}$_monthOffset months',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => _monthOffset++),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (monthMilestones.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Text(
                        'No crop milestones scheduled in this month.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _monthOffset++),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Check Next Month'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...monthMilestones.map(
                (m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: m.phase == WaterfallPhase.harvest
                          ? cs.tertiaryContainer
                          : cs.primaryContainer,
                      child: Text(
                        m.scheduledDate.substring(8, 10),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: m.phase == WaterfallPhase.harvest
                              ? cs.onTertiaryContainer
                              : cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      '${m.cropLabel}: ${m.title}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${m.scheduledDate} • ${phaseLabel(m.phase)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openMilestoneActionSheet(context, m),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ] else if (_viewMode == _PlannerViewMode.week) ...[
            Text(
              'Next 7 Days on Your Plan (${weekMilestones.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (weekMilestones.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No planting, feeding, or harvest milestones due in the next 7 days. Switch to Month to preview upcoming months.',
                  ),
                ),
              )
            else
              ...weekMilestones.map(
                (m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        m.daysFromToday == 0 ? 'Now' : '+${m.daysFromToday}d',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      '${m.cropLabel}: ${m.title}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${m.scheduledDate} • ${phaseLabel(m.phase)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openMilestoneActionSheet(context, m),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],

          // Interactive "Prepare Ahead (Next 14 Days)" Card
          Card(
            color: prepAlerts.isNotEmpty ? cs.tertiaryContainer : cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: prepAlerts.isNotEmpty ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Prepare Ahead (Next 14 Days)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (prepAlerts.isEmpty)
                    const Text(
                      'All upcoming 14-day preparations are complete. Tap any crop batch below to view its full schedule.',
                    )
                  else ...[
                    Text(
                      'Tap any item to see dosages and mark prepared:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ...prepAlerts.take(5).map(
                          (alert) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: cs.surface,
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: cs.primaryContainer,
                                child: Text(
                                  '${alert.daysFromToday}d',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              title: Text(
                                '${alert.cropLabel}: ${alert.title}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                alert.prepReminder ?? alert.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openMilestoneActionSheet(context, alert),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Crop Batches (${schedules.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Tap batch to expand',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (schedules.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('No crop batches planned yet.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _openNewPlanSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Start Your First Crop Plan'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...schedules.map(
              (schedule) => _BatchWaterfallCard(
                schedule: schedule,
                onTapMilestone: (m) => _openMilestoneActionSheet(context, m),
                onToggleMilestone: (milestoneId) =>
                    store.toggleMilestoneCompleted(schedule.plan.batchId, milestoneId),
                onLogHarvest: () => _pickActualHarvestDate(context, schedule),
                onShiftDate: () => _shiftBatchDateDialog(context, schedule),
                onDeleteBatch: () => _confirmRemoveBatch(context, schedule),
              ),
            ),
        ],
      ),
    );
  }
}

class _BatchWaterfallCard extends StatelessWidget {
  const _BatchWaterfallCard({
    required this.schedule,
    required this.onTapMilestone,
    required this.onToggleMilestone,
    required this.onLogHarvest,
    required this.onShiftDate,
    required this.onDeleteBatch,
  });

  final ComputedBatchSchedule schedule;
  final ValueChanged<ScheduledMilestone> onTapMilestone;
  final ValueChanged<String> onToggleMilestone;
  final VoidCallback onLogHarvest;
  final VoidCallback onShiftDate;
  final VoidCallback onDeleteBatch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final daysLeft = schedule.daysToHarvest;
    final harvestBadge = schedule.plan.actualHarvestDate != null
        ? 'Harvested ${schedule.plan.actualHarvestDate}'
        : daysLeft > 0
            ? '$daysLeft days to harvest'
            : daysLeft == 0
                ? 'Harvest window today!'
                : '${daysLeft.abs()}d past est. harvest';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          schedule.batchDisplayLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(
                label: Text(startModeLabel(schedule.plan.startMode)),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                backgroundColor: daysLeft <= 14 ? cs.primaryContainer : null,
                label: Text(harvestBadge),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text('Harvest: ${schedule.expectedHarvestDate}'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        children: [
          // Key Dates Summary Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (schedule.sowingDate != null)
                  Text('Sowing Date: ${schedule.sowingDate}'),
                if (schedule.expectedTransplantDate != null)
                  Text(
                    schedule.daysToTransplant != null
                        ? 'Expected Transplant: ${schedule.expectedTransplantDate} (${schedule.daysToTransplant! >= 0 ? "in ${schedule.daysToTransplant}d" : "${schedule.daysToTransplant!.abs()}d ago"})'
                        : 'Transplant Date: ${schedule.expectedTransplantDate}',
                  ),
                Text(
                  'Expected Harvest Date: ${schedule.expectedHarvestDate} (${schedule.fieldMaturityDays} field days)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (schedule.plan.actualHarvestDate != null && schedule.harvestVarianceDays != null)
                  Text(
                    'Actual Harvested: ${schedule.plan.actualHarvestDate} '
                    '(${schedule.harvestVarianceDays == 0 ? "on target" : "${schedule.harvestVarianceDays! > 0 ? "+" : ""}${schedule.harvestVarianceDays}d vs estimate"})',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onShiftDate,
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Set Planting Date'),
              ),
              OutlinedButton.icon(
                onPressed: onLogHarvest,
                icon: const Icon(Icons.agriculture_outlined, size: 18),
                label: Text(
                  schedule.plan.actualHarvestDate == null ? 'Log Actual Harvest' : 'Update Harvest',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onDeleteBatch,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
              ),
            ],
          ),

          const Divider(height: 22),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Crop Care Timeline (tap any step for details)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),

          ...schedule.milestones.map((m) {
            final isDone = schedule.plan.completedMilestoneIds.contains(m.id);
            final timingLabel = m.daysFromToday == 0
                ? 'Today'
                : m.daysFromToday > 0
                    ? 'In ${m.daysFromToday}d'
                    : '${m.daysFromToday.abs()}d ago';

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onTapMilestone(m),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: m.isPrepareAheadAlert && !isDone ? cs.tertiary : cs.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isDone,
                      onChanged: (_) => onToggleMilestone(m.id),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                phaseLabel(m.phase).toUpperCase(),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const Spacer(),
                              Text(
                                '${m.scheduledDate} ($timingLabel)',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(m.summary, style: Theme.of(context).textTheme.bodySmall),
                          if (m.conventionalInput != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Input: ${m.conventionalInput}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AddCropPlanSheet extends StatefulWidget {
  const _AddCropPlanSheet({required this.store});

  final OfflineGardenStore store;

  @override
  State<_AddCropPlanSheet> createState() => _AddCropPlanSheetState();
}

class _AddCropPlanSheetState extends State<_AddCropPlanSheet> {
  CropPlannerProfile _selectedProfile = kTanzaniaPlannerProfiles.first;
  BatchStartMode _startMode = kTanzaniaPlannerProfiles.first.defaultStartMode;
  DateTime _anchorDate = DateTime.now();
  int _plantCount = 30;
  bool _enableSuccession = false;
  int _successionIntervalDays = 21;
  int _successionBatches = 3;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(_anchorDate.year - 1),
      lastDate: DateTime(_anchorDate.year + 2),
    );
    if (picked != null) {
      setState(() => _anchorDate = picked);
    }
  }

  void _commitPlan() {
    final anchorIso = formatIsoDate(_anchorDate);
    if (_enableSuccession) {
      widget.store.addSuccessionPlan(
        cropProfileId: _selectedProfile.profileId,
        startMode: _startMode,
        firstAnchorDate: anchorIso,
        intervalDays: _successionIntervalDays,
        batchCount: _successionBatches,
        plantCountPerBatch: _plantCount,
      );
    } else {
      widget.store.addCropBatch(
        cropProfileId: _selectedProfile.profileId,
        startMode: _startMode,
        anchorDate: anchorIso,
        plantCount: _plantCount,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final previewIso = formatIsoDate(_anchorDate);
    final previewSchedule = computeBatchSchedule(
      CropBatchPlan(
        batchId: 'preview',
        cropProfileId: _selectedProfile.profileId,
        startMode: _startMode,
        anchorDate: previewIso,
        plantCount: _plantCount,
      ),
      formatIsoDate(DateTime.now()),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan a New Crop Batch',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Crop selector
            DropdownButtonFormField<String>(
              initialValue: _selectedProfile.profileId,
              decoration: const InputDecoration(
                labelText: 'Crop / Variety',
                border: OutlineInputBorder(),
              ),
              items: kTanzaniaPlannerProfiles
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.profileId,
                      child: Text('${p.commonName} (${p.localNameSw}) — ${p.totalMaturityDays}d'),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                final prof = findPlannerProfile(val);
                setState(() {
                  _selectedProfile = prof;
                  _startMode = prof.defaultStartMode;
                  _successionIntervalDays = prof.defaultSuccessionIntervalDays;
                });
              },
            ),

            const SizedBox(height: 12),

            // Start mode selector
            Text('How are you starting?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<BatchStartMode>(
              segments: const [
                ButtonSegment(value: BatchStartMode.boughtSeedlings, label: Text('Seedlings')),
                ButtonSegment(value: BatchStartMode.seedNursery, label: Text('From Seed')),
                ButtonSegment(value: BatchStartMode.directSeed, label: Text('Direct')),
              ],
              selected: {_startMode},
              onSelectionChanged: (sel) => setState(() => _startMode = sel.first),
            ),

            const SizedBox(height: 12),

            // Anchor date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                _startMode == BatchStartMode.boughtSeedlings
                    ? 'Transplant Date'
                    : 'Sowing / Planting Date',
              ),
              subtitle: Text(previewIso),
              trailing: OutlinedButton(onPressed: _pickDate, child: const Text('Change')),
            ),

            // Plant count slider (for fertilizer calculation / tracking)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Number of plants: $_plantCount'),
                Text(
                  '${previewSchedule.fieldMaturityDays} field days',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Slider(
              value: _plantCount.toDouble(),
              min: 5,
              max: 200,
              divisions: 39,
              label: '$_plantCount plants',
              onChanged: (v) => setState(() => _plantCount = v.round()),
            ),

            // Succession planting toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Succession Planting'),
              subtitle: const Text('Schedule sequential batches for continuous harvest'),
              value: _enableSuccession,
              onChanged: (v) => setState(() => _enableSuccession = v),
            ),

            if (_enableSuccession) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _successionIntervalDays,
                      decoration: const InputDecoration(
                        labelText: 'Interval (days)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [14, 21, 28, 30, 45, 60]
                          .map((d) => DropdownMenuItem(value: d, child: Text('Every $d days')))
                          .toList(),
                      onChanged: (v) => setState(() => _successionIntervalDays = v ?? 21),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _successionBatches,
                      decoration: const InputDecoration(
                        labelText: 'Batches',
                        border: OutlineInputBorder(),
                      ),
                      items: const [2, 3, 4, 5, 6]
                          .map((b) => DropdownMenuItem(value: b, child: Text('$b plantings')))
                          .toList(),
                      onChanged: (v) => setState(() => _successionBatches = v ?? 3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Live prediction summary card (dates only — no yield quantity estimation in MVP)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (previewSchedule.expectedTransplantDate != null &&
                        _startMode == BatchStartMode.seedNursery)
                      Text('Expected Transplant Date: ${previewSchedule.expectedTransplantDate}'),
                    Text(
                      'Expected Harvest Date: ${previewSchedule.expectedHarvestDate}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_enableSuccession)
                      Text(
                        'Final Batch Planting: ${addDaysIso(previewIso, _successionIntervalDays * (_successionBatches - 1))}',
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _commitPlan,
                child: Text(
                  _enableSuccession
                      ? 'Create $_successionBatches Succession Batches'
                      : 'Add Crop Batch',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

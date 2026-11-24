import 'package:flutter/material.dart';

import '../data/crop_field_library.dart';
import '../data/offline_garden_store.dart';
import '../models/crop_planner_models.dart';
import '../models/garden_models.dart';
import '../widgets/brand_logo.dart';
import 'offline_checklist_screen.dart';
import 'task_detail_screen.dart';

/// Crop Detail & Living Personal Crop Library screen.
/// Opened by tapping any crop in `My Garden` so farmers can inspect their
/// personalized homestead setup, harvest plan, growing personal notes/Mentor advice,
/// and peer-to-peer farmer field notes (100% offline).
class CropDetailScreen extends StatelessWidget {
  const CropDetailScreen({
    super.key,
    required this.store,
    required this.crop,
  });

  final OfflineGardenStore store;
  final CropModel crop;

  DateTime? _parseIsoDate(String iso) {
    if (iso.trim().isEmpty) return null;
    try {
      return DateTime.parse(iso.trim());
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  ComputedBatchSchedule? _matchingBatch() {
    final target = crop.commonName.toLowerCase();
    for (final schedule in store.computedBatchSchedules) {
      if (schedule.plan.cropProfileId == crop.cropProfileId ||
          schedule.profile.commonName.toLowerCase().contains(target) ||
          target.contains(schedule.profile.commonName.toLowerCase())) {
        return schedule;
      }
    }
    return null;
  }

  Future<void> _openAddNoteDialog(BuildContext context) async {
    final noteCtrl = TextEditingController();
    String selectedSource = 'my_note';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add to ${crop.commonName} Library'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record what you observed, a challenge you faced, or an action that worked this season:',
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'my_note', label: Text('Field Note')),
                    ButtonSegment(value: 'action_taken', label: Text('Action Taken')),
                  ],
                  selected: {selectedSource},
                  onSelectionChanged: (sel) => setDialogState(() => selectedSource = sel.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Your note',
                    hintText: 'e.g., Added dry grass mulch after heavy rain; spacing 2 foot-lengths worked well.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save to Library'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && noteCtrl.text.trim().isNotEmpty) {
      await store.addCropLibraryNote(
        cropProfileId: crop.cropProfileId,
        cropName: crop.commonName,
        source: selectedSource,
        content: noteCtrl.text.trim(),
      );
    }
    noteCtrl.dispose();
  }

  String _noteSourceLabel(String source) {
    switch (source) {
      case 'mentor_advice':
        return 'Saved Mentor Advice';
      case 'action_taken':
        return 'Action Taken';
      default:
        return 'My Field Note';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final guide = fieldGuideForCrop(
      profileId: crop.cropProfileId,
      commonName: crop.commonName,
      localNameSw: crop.localNameSw,
    );

    final titleLabel = crop.localNameSw.isNotEmpty
        ? '${crop.commonName} (${crop.localNameSw})'
        : crop.commonName;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final batchSchedule = _matchingBatch();
        final plantedDate = _parseIsoDate(crop.plantingDate);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        DateTime? expectedHarvestMin;
        DateTime? expectedHarvestMax;
        if (batchSchedule != null) {
          expectedHarvestMin = _parseIsoDate(batchSchedule.expectedHarvestDate);
        } else if (plantedDate != null) {
          expectedHarvestMin = plantedDate.add(Duration(days: guide.daysToHarvestMin));
          expectedHarvestMax = plantedDate.add(Duration(days: guide.daysToHarvestMax));
        }

        final int? daysUntilHarvest =
            expectedHarvestMin != null ? expectedHarvestMin.difference(today).inDays : null;

        final cropTasks = store.tasks
            .where((t) =>
                t.cropId == crop.cropId ||
                t.cropName.toLowerCase() == crop.commonName.toLowerCase())
            .take(5)
            .toList();

        final personalNotes = store.notesForCrop(
          cropProfileId: crop.cropProfileId,
          cropName: crop.commonName,
        );

        final homesteadAdvice = homesteadSetupAdvice(
          plot: store.activePlot,
          guide: guide,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(crop.commonName),
            actions: [
              IconButton(
                tooltip: 'Add personal note',
                icon: const Icon(Icons.note_add_outlined),
                onPressed: () => _openAddNoteDialog(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLogo(size: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${guide.family} • ${crop.plantingMethod == PlantingMethod.directSeed ? 'Direct Seed' : 'Transplant'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                const Chip(
                                  avatar: Icon(Icons.offline_pin_outlined, size: 16),
                                  label: Text('My Living Library'),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Chip(
                                  label: Text('Stage: ${crop.growthStage}'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Personalized Homestead Setup & Practical Measurements Card
              Card(
                color: cs.primaryContainer.withValues(alpha: 0.45),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten_outlined, size: 20, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tailored for Your Homestead (${store.activePlot?.regionName ?? 'Your Plot'})',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(homesteadAdvice, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Crop Plan & Harvest Timeline Card
              Card(
                color: cs.secondaryContainer.withValues(alpha: 0.45),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available_outlined, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Your Crop Plan & Harvest Window',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PlanRow(
                        label: 'Planted',
                        value: crop.plantingDate.isNotEmpty ? crop.plantingDate : 'Not set',
                      ),
                      if (expectedHarvestMin != null)
                        _PlanRow(
                          label: 'Expected Harvest',
                          value: expectedHarvestMax != null
                              ? '${_formatDate(expectedHarvestMin)} – ${_formatDate(expectedHarvestMax)}'
                              : _formatDate(expectedHarvestMin),
                        ),
                      if (daysUntilHarvest != null)
                        _PlanRow(
                          label: 'Countdown',
                          value: daysUntilHarvest > 0
                              ? 'In ~$daysUntilHarvest days (${guide.daysToHarvestMin}–${guide.daysToHarvestMax}d maturity)'
                              : daysUntilHarvest == 0
                                  ? 'Harvest window starts today!'
                                  : 'In harvest window (${daysUntilHarvest.abs()}d past target)',
                        ),
                      if (batchSchedule != null)
                        _PlanRow(
                          label: 'Planner Batch',
                          value:
                              '${batchSchedule.profile.commonName} • ${batchSchedule.plan.plantCount} plants (${batchSchedule.totalMaturityDays}d)',
                        ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => OfflineChecklistScreen(store: store),
                            ),
                          );
                        },
                        icon: const Icon(Icons.checklist_rtl_outlined),
                        label: const Text("Make Today's Care Checklist (Offline AI)"),
                      ),
                    ],
                  ),
                ),
              ),

              // Living Farmer Notes & Saved Mentor Advice
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'My ${crop.commonName} Notes & Mentor Advice (${personalNotes.length})',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _openAddNoteDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Note'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (personalNotes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Your personal ${crop.commonName} library grows with every season. '
                      'Tap "Add Note" to log challenges and actions taken, or tap "Save to Crop Library" '
                      'on any reply in Garden Mentor.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ...personalNotes.map(
                  (note) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Chip(
                                label: Text(_noteSourceLabel(note.source)),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                note.createdAtIso,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                tooltip: 'Delete note',
                                onPressed: () => store.deleteCropLibraryNote(note.noteId),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(note.content, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ),

              if (cropTasks.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Upcoming Care Tasks',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...cropTasks.map(
                  (task) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.task_alt_outlined),
                      title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${task.scheduledDate} • ${task.estimatedDurationMinutes} min'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TaskDetailScreen(
                              task: task,
                              store: store,
                              canComplete: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                'Farmer-to-Farmer Field Notes — ${guide.commonName}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _LibrarySectionCard(
                icon: Icons.water_drop_outlined,
                title: 'Watering & Spacing',
                body: '${guide.wateringGuide}\n\nSpacing: ${guide.spacingGuide}',
              ),
              const SizedBox(height: 8),
              _LibrarySectionCard(
                icon: Icons.wb_sunny_outlined,
                title: 'Season & Weather Notes',
                body: guide.seasonAndWeatherNotes,
              ),
              const SizedBox(height: 8),
              _LibraryBulletCard(
                icon: Icons.bug_report_outlined,
                title: 'What to Look Out For (Pests & Early Signs)',
                items: guide.whatToLookFor,
              ),
              const SizedBox(height: 8),
              _LibraryBulletCard(
                icon: Icons.timeline_outlined,
                title: 'Stage-by-Stage Homestead Care',
                items: guide.stageCareTips,
              ),
              const SizedBox(height: 8),
              _LibrarySectionCard(
                icon: Icons.science_outlined,
                title: 'Feeding & Soil Care',
                body: guide.nutritionNotes,
              ),

              const SizedBox(height: 14),
              Text(
                'Peer-to-peer homestead field notes — always available offline, and grows richer as you save your own observations and Mentor advice.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySectionCard extends StatelessWidget {
  const _LibrarySectionCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _LibraryBulletCard extends StatelessWidget {
  const _LibraryBulletCard({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

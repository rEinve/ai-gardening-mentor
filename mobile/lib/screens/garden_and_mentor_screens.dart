import 'package:flutter/material.dart';

import '../data/crop_field_library.dart';
import '../data/offline_garden_store.dart';
import '../models/garden_models.dart';
import '../widgets/brand_logo.dart';
import 'account_screen.dart';
import 'crop_detail_screen.dart';
import 'offline_checklist_screen.dart';

/// `/garden` — Active plots and crops. Personal Farm Contacts live in Account.
class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key, required this.store});

  final OfflineGardenStore store;

  Future<void> _confirmRetireCrop(BuildContext context, dynamic crop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${crop.commonName}?'),
        content: Text(
          'Remove ${crop.commonName} from your garden? Future care tasks for this crop will be cleared.',
        ),
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
      await store.retireCrop(crop.cropId as String);
    }
  }

  String _formatPlotType(PlotType type) {
    switch (type) {
      case PlotType.raisedBed:
        return 'Raised Bed';
      case PlotType.inGround:
        return 'In-Ground';
      case PlotType.container:
        return 'Containers';
      case PlotType.indoorWindow:
        return 'Indoor Window';
    }
  }

  String _formatRainExposure(RainExposure exposure) {
    switch (exposure) {
      case RainExposure.exposed:
        return 'Exposed';
      case RainExposure.sheltered:
        return 'Sheltered';
      case RainExposure.indoor:
        return 'Indoor';
    }
  }

  void _openCompostGuideSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Icon(Icons.compost_outlined, color: cs.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Homestead Compost & Bed Health',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              color: cs.primaryContainer.withValues(alpha: 0.45),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Bed health comes first: industrial fertilizer alone struggles in soil with low organic matter. '
                  'Well-rotted compost builds living soil so every crop responds better to feeding.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '1. Collect Manure in the Dry Off-Season (June–July)',
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '• After the main rains, cow sheds dry out and dry manure is widely available and much cheaper.\n'
              '• Gather enough manure early so it finishes composting before dry-season irrigated planting begins.\n'
              '• Avoid putting raw, fresh manure straight onto beds — it can burn tender roots and bring weed seeds.',
            ),
            const SizedBox(height: 12),
            Text(
              '2. How to Make Compost at Home (Pit or Heap)',
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '• Pit (best for dry/hot areas like Dodoma) or Heap (best for rainy/wet areas): layer dry grass or maize stalks + kitchen/garden greens + cow manure.\n'
              '• Cover the heap or pit with banana leaves, dry grass, or a tarp so moisture and heat stay inside.\n'
              '• Water regularly so the pile stays as damp as a wrung-out sponge (never soggy), and turn every 2–3 weeks.\n'
              '• Ready to use when dark, crumbly, cool, and earthy-smelling — mix into beds before planting.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  void _openTrellisGuideSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
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
                Icon(Icons.fence_outlined, color: cs.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trellis & Support Prep',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'If you are growing Tomatoes (Nyanya) or Cucumbers (Tango), gather poles, bamboo, and sisal twine BEFORE flowering:\n\n'
              '• Single-Stake Tying: One sturdy pole (~150 cm tall) beside each tomato plant, tied loosely in a figure-8 so stems are not cut.\n'
              '• Florida Weave: Sturdy posts every 2–3 plants with horizontal sisal twine woven along both sides of the row as plants grow.\n'
              '• Cucumber A-Frame / String Trellis: Keeps vines off wet soil for straighter fruit, better airflow, and far less fungal spot.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plot = store.activePlot;
    final activeCrops = store.crops.where((c) => !c.isRetired).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Garden'),
        actions: [
          IconButton(
            tooltip: 'My Account & Farm Contacts',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => AccountScreen(store: store)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (plot != null)
            Card(
              child: ListTile(
                leading: const BrandLogo(size: 28),
                title: Text(plot.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${plot.regionName} • ${_formatPlotType(plot.plotType)} • ${_formatRainExposure(plot.rainExposure)}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => AccountScreen(store: store)),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.45),
            child: ListTile(
              leading: Icon(
                Icons.offline_pin_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text(
                'Offline Care Checklist & Field Guide',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Generate today’s care checklist on-device or tap any crop below for its offline guide.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OfflineChecklistScreen(store: store),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openCompostGuideSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.compost_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Compost & Bed Health',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pit/heap guide & off-season manure prep',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openTrellisGuideSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.fence_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Trellis & Support Prep',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Stakes & Florida Weave for tomato/cucumber',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Active Crops (${activeCrops.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap any crop for its harvest timeline, care plan & offline field library.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (activeCrops.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No active crops in this plot yet. Use Crop Planner to add your next crop batch.'),
              ),
            )
          else
            ...activeCrops.map((c) {
              final guide = fieldGuideForCrop(
                profileId: c.cropProfileId,
                commonName: c.commonName,
                localNameSw: c.localNameSw,
              );
              return Card(
                child: ListTile(
                  leading: const BrandLogo(size: 22),
                  title: Text('${c.commonName} (${c.localNameSw})'),
                  subtitle: Text(
                    'Planted ${c.plantingDate} • Stage: ${c.growthStage} • ~${guide.daysToHarvestMin}–${guide.daysToHarvestMax}d to harvest',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove crop',
                        onPressed: () => _confirmRetireCrop(context, c),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CropDetailScreen(store: store, crop: c),
                      ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// `/mentor` — Phase 3 Grounded Mentor Chat shell (wired in Phase 3).
class MentorPlaceholderScreen extends StatelessWidget {
  const MentorPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Garden Mentor')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Peer-to-peer Garden Mentor with your active Tanzania plot and crops.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

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
      appBar: AppBar(title: const Text('Organic Mentor')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Grounded Mentor Chat (Phase 3)\n\nWill inject your active Tanzania plot/crops and cite reviewed EWS-KT GrowHow & extension passages.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

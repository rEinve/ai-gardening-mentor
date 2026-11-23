import 'package:flutter/material.dart';

import '../data/offline_garden_store.dart';
import 'account_screen.dart';

/// `/garden` — Active plots and crops. Personal Farm Contacts live in Account.
class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key, required this.store});

  final OfflineGardenStore store;

  @override
  Widget build(BuildContext context) {
    final plot = store.activePlot;
    final crops = store.crops;

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
                leading: const Icon(Icons.yard_outlined),
                title: Text(plot.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${plot.regionName} • ${plot.plotType.name} • ${plot.rainExposure.name}'),
              ),
            ),
          const SizedBox(height: 16),
          Text('Active Crops (${crops.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...crops.map(
            (c) => Card(
              child: ListTile(
                leading: const Icon(Icons.eco_outlined),
                title: Text('${c.commonName} (${c.localNameSw})'),
                subtitle: Text('Planted ${c.plantingDate} • Stage: ${c.growthStage}'),
                trailing: Chip(label: Text(c.isRetired ? 'Retired' : 'Active')),
              ),
            ),
          ),
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

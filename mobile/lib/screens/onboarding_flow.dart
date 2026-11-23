import 'package:flutter/material.dart';

import '../data/offline_garden_store.dart';
import '../data/tanzania_crops.dart';
import '../models/garden_models.dart';
import '../widgets/brand_logo.dart';

/// 3-screen Tanzania onboarding flow per docs/app-_flow.md:
/// 1. Welcome
/// 2. Select Tanzania Crops (at least 1 required)
/// 3. Plot Details (Region, Plot Type, Rain Exposure, Sunlight) -> initializeGarden
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.store});

  final OfflineGardenStore store;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  final Set<String> _selectedCropIds = {'tz_tomato', 'tz_amaranth'};
  final TextEditingController _plotNameCtrl = TextEditingController(text: 'Home Garden Bed');
  String _selectedRegion = kTanzaniaRegions.first;
  PlotType _plotType = PlotType.raisedBed;
  RainExposure _rainExposure = RainExposure.exposed;
  SunlightExposure _sunlight = SunlightExposure.fullSun;

  @override
  void dispose() {
    _plotNameCtrl.dispose();
    super.dispose();
  }

  void _submitGarden() {
    final chosen = kTanzaniaCrops
        .where((c) => _selectedCropIds.contains(c.profileId))
        .toList();
    widget.store.initializeGarden(
      plotName: _plotNameCtrl.text,
      regionName: _selectedRegion,
      plotType: _plotType,
      rainExposure: _rainExposure,
      sunlightExposure: _sunlight,
      selectedCrops: chosen,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup (${_step + 1} of 3)'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_step) {
            0 => _buildWelcome(cs),
            1 => _buildCropSelect(cs),
            _ => _buildPlotDetails(cs),
          },
        ),
      ),
    );
  }

  Widget _buildWelcome(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const BrandLogo(size: 64),
        const SizedBox(height: 16),
        Text(
          'Grow Vegetables in Tanzania with Calm Confidence',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Daily 5-minute care habits built for real soil, containers, and raised beds — working offline outdoors with metric units.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Start My Garden'),
          ),
        ),
      ],
    );
  }

  Widget _buildCropSelect(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What are you growing?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text('Choose at least one Tanzania household vegetable crop.'),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: kTanzaniaCrops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final crop = kTanzaniaCrops[index];
              final selected = _selectedCropIds.contains(crop.profileId);
              return CheckboxListTile(
                value: selected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
                ),
                title: Text('${crop.commonName} (${crop.localNameSw})'),
                subtitle: Text(crop.family),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedCropIds.add(crop.profileId);
                    } else {
                      _selectedCropIds.remove(crop.profileId);
                    }
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selectedCropIds.isEmpty ? null : () => setState(() => _step = 2),
            child: Text('Continue (${_selectedCropIds.length} selected)'),
          ),
        ),
      ],
    );
  }

  Widget _buildPlotDetails(ColorScheme cs) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about your plot',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plotNameCtrl,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: 'Plot name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedRegion,
            decoration: const InputDecoration(
              labelText: 'Tanzania Region',
              border: OutlineInputBorder(),
            ),
            items: kTanzaniaRegions
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedRegion = val);
            },
          ),
          const SizedBox(height: 16),
          const Text('Plot Type', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PlotType.values.map((t) {
              return ChoiceChip(
                label: Text(t.name),
                selected: _plotType == t,
                onSelected: (_) => setState(() => _plotType = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Rain Exposure', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: RainExposure.values.map((r) {
              return ChoiceChip(
                label: Text(r.name),
                selected: _rainExposure == r,
                onSelected: (_) => setState(() => _rainExposure = r),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Sunlight', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: SunlightExposure.values.map((s) {
              return ChoiceChip(
                label: Text(s.name),
                selected: _sunlight == s,
                onSelected: (_) => setState(() => _sunlight = s),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitGarden,
              icon: const Icon(Icons.check),
              label: const Text('Create 7-Day Care Plan'),
            ),
          ),
        ],
      ),
    );
  }
}

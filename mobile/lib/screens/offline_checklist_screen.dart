import 'dart:async';
import 'package:flutter/material.dart';

import '../data/offline_garden_store.dart';
import '../data/reviewed_tomato_guide.dart';
import '../services/checklist_storage.dart';
import '../services/hybrid_checklist_adapter_factory.dart';
import '../services/hybrid_checklist_contract.dart';

/// "Offline Care Checklist" — Focused Firebase AI Logic Hybrid Inference feature.
///
/// Generates up to 3 concise daily care tasks grounded in the bundled
/// Reviewed Tanzania Tomato Field Guide + crop stage + current observation.
/// Reports genuine SDK-provided `inferenceSource` ("Generated on this device" vs
/// "Generated in cloud") and measured elapsed time. Never fabricates AI answers.
class OfflineChecklistScreen extends StatefulWidget {
  const OfflineChecklistScreen({
    super.key,
    required this.store,
    this.adapterOverride,
  });

  final OfflineGardenStore store;
  final HybridChecklistAdapter? adapterOverride;

  @override
  State<OfflineChecklistScreen> createState() => _OfflineChecklistScreenState();
}

class _OfflineChecklistScreenState extends State<OfflineChecklistScreen> {
  late final HybridChecklistAdapter _adapter;
  final TextEditingController _observationCtrl = TextEditingController();
  String _selectedStage = kTomatoGrowthStages[2];
  HybridInferenceMode _selectedMode = HybridInferenceMode.preferOnDevice;

  HybridCapabilityInfo _capability = const HybridCapabilityInfo(
    status: HybridCapabilityStatus.checking,
    message: 'Checking on-device Firebase AI Logic capability...',
  );

  bool _isPreparing = false;
  bool _isGenerating = false;
  String? _activeRequestId;
  StreamSubscription<HybridCapabilityInfo>? _prepareSub;

  HybridChecklistResult? _freshResult;
  PersistedChecklistRecord? _savedRecord;
  bool _showGuide = false;
  bool _showDevDetails = false;

  String get _accountKey =>
      widget.store.userEmail ?? widget.store.userDisplayName ?? 'signed_out';

  @override
  void initState() {
    super.initState();
    _adapter = widget.adapterOverride ?? createHybridChecklistAdapter();
    unawaited(_loadSavedAndProbe());
  }

  Future<void> _loadSavedAndProbe() async {
    final saved = await AccountChecklistStorage.load(_accountKey);
    if (mounted && saved != null) {
      setState(() {
        _savedRecord = saved;
        if (kTomatoGrowthStages.contains(saved.cropStage)) {
          _selectedStage = saved.cropStage;
        }
        if (_observationCtrl.text.isEmpty && saved.observation.isNotEmpty) {
          _observationCtrl.text = saved.observation;
        }
      });
    }
    await _checkCapability();
  }

  Future<void> _checkCapability() async {
    if (mounted) {
      setState(() {
        _capability = const HybridCapabilityInfo(
          status: HybridCapabilityStatus.checking,
          message: 'Checking device capability...',
        );
      });
    }
    final info = await _adapter.checkCapability();
    if (mounted) {
      setState(() => _capability = info);
    }
  }

  Future<void> _prepareOfflineAi() async {
    if (_isPreparing) return;
    setState(() => _isPreparing = true);
    await _prepareSub?.cancel();
    _prepareSub = _adapter.prepareModel().listen(
      (info) {
        if (!mounted) return;
        setState(() {
          _capability = info;
          if (info.status != HybridCapabilityStatus.downloading) {
            _isPreparing = false;
          }
        });
      },
      onError: (Object err) {
        if (!mounted) return;
        setState(() {
          _isPreparing = false;
          _capability = HybridCapabilityInfo(
            status: HybridCapabilityStatus.error,
            message: 'Model preparation failed: $err',
          );
        });
      },
      onDone: () {
        if (mounted && _isPreparing) {
          setState(() => _isPreparing = false);
        }
      },
    );
  }

  Future<void> _generateChecklist() async {
    if (_isGenerating) return;
    final region = widget.store.activePlot?.regionName ?? 'Tanzania';
    final requestId = 'chk_${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final prompt = buildCareChecklistPrompt(
      guideText: kReviewedTomatoGuideText,
      cropStage: _selectedStage,
      observation: _observationCtrl.text,
      regionName: region,
    );

    setState(() {
      _isGenerating = true;
      _activeRequestId = requestId;
      _freshResult = null;
    });

    final result = await _adapter.generateChecklist(
      prompt: prompt,
      mode: _selectedMode,
      requestId: requestId,
    );

    if (!mounted) return;
    if (_activeRequestId != requestId) return;

    setState(() {
      _isGenerating = false;
      _activeRequestId = null;
      _freshResult = result;
    });

    if (result.isSuccess) {
      final record = PersistedChecklistRecord(
        accountId: _accountKey,
        cropStage: _selectedStage,
        observation: _observationCtrl.text.trim(),
        checklistText: result.text!,
        savedAtIso: DateTime.now().toUtc().toIso8601String(),
        originalSource: result.inferenceSource.name,
        modelIdentity: result.modelIdentity,
      );
      await AccountChecklistStorage.save(record);
      if (mounted) {
        setState(() => _savedRecord = record);
      }
    }
  }

  Future<void> _cancelGeneration() async {
    final reqId = _activeRequestId;
    if (reqId == null) return;
    await _adapter.cancel(reqId);
    if (mounted) {
      setState(() {
        _isGenerating = false;
        _activeRequestId = null;
        _freshResult = HybridChecklistResult(
          requestId: reqId,
          inferenceSource: HybridInferenceSource.unknown,
          elapsedMs: 0,
          errorCode: 'CANCELLED',
          errorMessage: 'Generation cancelled.',
        );
      });
    }
  }

  @override
  void dispose() {
    if (_activeRequestId != null) {
      unawaited(_adapter.cancel(_activeRequestId!));
    }
    _prepareSub?.cancel();
    _observationCtrl.dispose();
    if (widget.adapterOverride == null) {
      _adapter.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final region = widget.store.activePlot?.regionName ?? 'Tanzania';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Care Checklist'),
        actions: [
          IconButton(
            tooltip: 'Re-check device capability',
            icon: const Icon(Icons.refresh),
            onPressed: _isPreparing || _isGenerating ? null : _checkCapability,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Honest Capability & Explicit Prepare Card
          Card(
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _capability.status == HybridCapabilityStatus.ready
                            ? Icons.offline_bolt_outlined
                            : _capability.status == HybridCapabilityStatus.downloadAvailable
                                ? Icons.download_for_offline_outlined
                                : _capability.status == HybridCapabilityStatus.downloading
                                    ? Icons.downloading
                                    : Icons.cloud_outlined,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _capabilityHeadline(_capability.status),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (_capability.message != null) ...[
                    const SizedBox(height: 6),
                    Text(_capability.message!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (_capability.status == HybridCapabilityStatus.downloading) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: _capability.downloadProgress),
                  ],
                  if (_capability.status == HybridCapabilityStatus.downloadAvailable ||
                      _capability.status == HybridCapabilityStatus.error) ...[
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _isPreparing ? null : _prepareOfflineAi,
                      icon: const Icon(Icons.download),
                      label: Text(
                        _capability.downloadSizeBytes != null
                            ? 'Prepare offline AI (${(_capability.downloadSizeBytes! / (1024 * 1024)).toStringAsFixed(0)} MB)'
                            : 'Prepare offline AI',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Bundled Reviewed Tomato Field Guide (Always readable offline)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text(kReviewedTomatoGuideTitle),
                  subtitle: const Text('Bundled offline reference — always available without internet'),
                  trailing: Icon(_showGuide ? Icons.expand_less : Icons.expand_more),
                  onTap: () => setState(() => _showGuide = !_showGuide),
                ),
                if (_showGuide)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      kReviewedTomatoGuideText.trim(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Checklist Generator Form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Make today\'s care checklist ($region)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStage,
                    decoration: const InputDecoration(
                      labelText: 'Tomato Crop Stage',
                      border: OutlineInputBorder(),
                    ),
                    items: kTomatoGrowthStages
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: _isGenerating
                        ? null
                        : (v) {
                            if (v != null) setState(() => _selectedStage = v);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _observationCtrl,
                    enabled: !_isGenerating,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'What did you notice today?',
                      hintText: 'e.g., Bottom two leaves turned yellow after yesterday\'s rain',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isGenerating ? null : _generateChecklist,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.checklist),
                          label: Text(_isGenerating ? 'Generating...' : 'Make Today\'s Care Checklist'),
                        ),
                      ),
                      if (_isGenerating) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _cancelGeneration,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Fresh Generation Result (or retryable error)
          if (_freshResult != null) ...[
            Card(
              color: _freshResult!.isSuccess ? cs.primaryContainer.withValues(alpha: 0.35) : cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_freshResult!.isSuccess)
                          Chip(
                            avatar: Icon(
                              _freshResult!.inferenceSource == HybridInferenceSource.onDevice
                                  ? Icons.phone_android
                                  : Icons.cloud_done_outlined,
                              size: 16,
                            ),
                            label: Text(_freshResult!.userFacingSourceLabel),
                          ),
                        if (_freshResult!.elapsedMs > 0)
                          Chip(label: Text('${_freshResult!.elapsedMs} ms')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_freshResult!.isSuccess)
                      Text(_freshResult!.text!, style: Theme.of(context).textTheme.bodyMedium)
                    else ...[
                      Text(
                        'Unable to generate a new checklist right now.',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _freshResult!.errorMessage ??
                            'On-device model is unavailable and cloud inference could not be reached. '
                                'Your bundled Tomato Field Guide above remains available offline.',
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _isGenerating ? null : _generateChecklist,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 5. Persisted Account-Scoped Saved Checklist (explicitly marked as Saved)
          if (_savedRecord != null && (_freshResult == null || !_freshResult!.isSuccess)) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Chip(
                          avatar: Icon(Icons.bookmark_outline, size: 16),
                          label: Text('Saved checklist (not fresh inference)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stage: ${_savedRecord!.cropStage}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(_savedRecord!.checklistText),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 6. Judge / Developer Diagnostics Panel (hidden behind toggle)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.developer_mode_outlined),
                  title: const Text('Judge & Developer Details'),
                  subtitle: Text('Mode: ${_selectedMode.name} • Status: ${_capability.status.name}'),
                  trailing: Icon(_showDevDetails ? Icons.expand_less : Icons.expand_more),
                  onTap: () => setState(() => _showDevDetails = !_showDevDetails),
                ),
                if (_showDevDetails)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<HybridInferenceMode>(
                          segments: const [
                            ButtonSegment(
                              value: HybridInferenceMode.preferOnDevice,
                              label: Text('Prefer Local'),
                            ),
                            ButtonSegment(
                              value: HybridInferenceMode.onlyOnDevice,
                              label: Text('Only Local'),
                            ),
                            ButtonSegment(
                              value: HybridInferenceMode.onlyInCloud,
                              label: Text('Only Cloud'),
                            ),
                          ],
                          selected: {_selectedMode},
                          onSelectionChanged: (sel) => setState(() => _selectedMode = sel.first),
                        ),
                        const SizedBox(height: 10),
                        Text('Platform: ${_capability.platformLabel}'),
                        Text('Capability Status: ${_capability.status.name}'),
                        Text('Model Identity: ${_freshResult?.modelIdentity ?? _capability.modelIdentity ?? "Not reported"}'),
                        Text('Last Request ID: ${_freshResult?.requestId ?? "None"}'),
                        Text('SDK Inference Source: ${_freshResult?.inferenceSource.name ?? "None"}'),
                        Text('Elapsed: ${_freshResult != null ? "${_freshResult!.elapsedMs} ms" : "N/A"}'),
                        if (_freshResult?.errorCode != null)
                          Text('Error: ${_freshResult!.errorCode} — ${_freshResult!.errorMessage}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capabilityHeadline(HybridCapabilityStatus status) {
    switch (status) {
      case HybridCapabilityStatus.checking:
        return 'Checking on-device AI capability...';
      case HybridCapabilityStatus.ready:
        return 'On-device AI ready (offline checklist supported)';
      case HybridCapabilityStatus.downloadAvailable:
        return 'On-device AI available to prepare';
      case HybridCapabilityStatus.downloading:
        return 'Preparing on-device AI...';
      case HybridCapabilityStatus.unsupported:
        return 'On-device AI unsupported on this device (Cloud fallback when online)';
      case HybridCapabilityStatus.error:
        return 'Capability check error';
    }
  }
}

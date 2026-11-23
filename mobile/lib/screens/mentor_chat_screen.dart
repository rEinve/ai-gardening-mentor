import 'dart:async';
import 'package:flutter/material.dart';

import '../data/offline_garden_store.dart';
import '../data/tanzania_crops.dart';
import '../models/garden_models.dart';
import '../services/garden_backend_client.dart';
import '../services/hybrid_mentor_responder.dart';
import '../services/photo_picker.dart';
import '../widgets/brand_logo.dart';
import 'agro_supplier_sheet.dart';
import 'triage_flow.dart';

class _ChatBubble {
  const _ChatBubble({
    required this.isUser,
    required this.content,
    required this.timestampIso,
    this.insufficientEvidence = false,
    this.isStreaming = false,
    this.citations = const [],
    this.modeBadge,
  });

  final bool isUser;
  final String content;
  final String timestampIso;
  final bool insufficientEvidence;
  final bool isStreaming;
  final List<SourceCitation> citations;
  final String? modeBadge;

  _ChatBubble copyWith({
    String? content,
    bool? insufficientEvidence,
    bool? isStreaming,
    List<SourceCitation>? citations,
    String? modeBadge,
  }) {
    return _ChatBubble(
      isUser: isUser,
      content: content ?? this.content,
      timestampIso: timestampIso,
      insufficientEvidence: insufficientEvidence ?? this.insufficientEvidence,
      isStreaming: isStreaming ?? this.isStreaming,
      citations: citations ?? this.citations,
      modeBadge: modeBadge ?? this.modeBadge,
    );
  }
}

/// `/mentor` — Phase 3 Grounded Mentor Chat with garden context inspection,
/// offline draft retention, live SSE streaming (`processMentorChatMessage`),
/// citation display, and archive confirmation (`archiveChatSession`).
class MentorChatScreen extends StatefulWidget {
  const MentorChatScreen({super.key, required this.store});

  final OfflineGardenStore store;

  @override
  State<MentorChatScreen> createState() => _MentorChatScreenState();
}

class _MentorChatScreenState extends State<MentorChatScreen> {
  final TextEditingController _draftCtrl = TextEditingController();
  final List<_ChatBubble> _messages = [];
  StreamSubscription<MentorSseEvent>? _streamSub;
  String _sessionId = 'sess_${DateTime.now().toUtc().millisecondsSinceEpoch}';
  bool _isOffline = false;
  bool _hasLocalModelDownloaded = false;
  bool _isArchived = false;
  bool _isStreaming = false;

  static const List<String> _suggestedPrompts = [
    'What fertilizer should I prepare next for my crops?',
    'When should I water my tomatoes in Dar es Salaam?',
    'How do I check for pests on leaf undersides?',
    'When is Mchicha ready to harvest?',
  ];

  @override
  void dispose() {
    _streamSub?.cancel();
    _draftCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isStreaming) return;

    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    final region = widget.store.activePlot?.regionName ?? 'Tanzania';
    final cropSummary = widget.store.crops.map((c) => c.commonName).join(', ');
    final nextAlert = widget.store.upcomingPrepAlerts.isNotEmpty
        ? widget.store.upcomingPrepAlerts.first
        : null;

    final route = HybridMentorResponder.selectRoute(
      isOnline: !_isOffline,
      hasLocalModelDownloaded: _hasLocalModelDownloaded,
    );

    if (route == HybridAiRoute.onDeviceLocalOffline ||
        route == HybridAiRoute.offlineSafeGuide) {
      final resolution = route == HybridAiRoute.onDeviceLocalOffline
          ? HybridMentorResponder.buildOnDeviceShortAnswer(
              regionName: region,
              cropsSummary: cropSummary,
              userQuestion: trimmed,
              nextPrepAlert: nextAlert,
            )
          : HybridMentorResponder.buildOfflineSafeGuide(
              regionName: region,
              cropsSummary: cropSummary,
              userQuestion: trimmed,
              nextPrepAlert: nextAlert,
            );
      setState(() {
        _messages.add(_ChatBubble(isUser: true, content: trimmed, timestampIso: nowIso));
        _messages.add(
          _ChatBubble(
            isUser: false,
            content: resolution.content,
            timestampIso: nowIso,
            modeBadge: resolution.badgeLabel,
            citations: const [kGrowHowFixtureCitation],
          ),
        );
        _draftCtrl.clear();
      });
      widget.store.recordChatLog(
        sessionId: _sessionId,
        question: trimmed,
        answer: resolution.content,
        dateIso: nowIso.substring(0, 10),
      );
      return;
    }

    final backend = widget.store.backend;

    if (backend != null) {
      final ts = now.millisecondsSinceEpoch;
      final requestId = 'req_chat_$ts';
      final messageId = 'msg_$ts';

      setState(() {
        _isStreaming = true;
        _messages.add(_ChatBubble(isUser: true, content: trimmed, timestampIso: nowIso));
        _messages.add(
          _ChatBubble(
            isUser: false,
            content: '',
            timestampIso: nowIso,
            isStreaming: true,
          ),
        );
        _draftCtrl.clear();
      });

      final assistantIdx = _messages.length - 1;
      await _streamSub?.cancel();
      _streamSub = backend
          .streamMentorChat(
            requestId: requestId,
            sessionId: _sessionId,
            messageId: messageId,
            text: trimmed,
            plotId: widget.store.activePlot?.plotId,
          )
          .listen(
            (ev) {
              if (!mounted) return;
              if (ev.event == 'delta') {
                final chunk = (ev.data['text'] as String?) ?? '';
                if (chunk.isNotEmpty) {
                  setState(() {
                    _messages[assistantIdx] = _messages[assistantIdx].copyWith(
                      content: '${_messages[assistantIdx].content}$chunk',
                    );
                  });
                }
              } else if (ev.event == 'done') {
                final status = ev.data['validationStatus'] as String?;
                final rawRefs = (ev.data['sourceRefs'] as List<dynamic>?) ?? const [];
                final citations = rawRefs.map((entry) {
                  final m = Map<String, dynamic>.from(entry as Map);
                  return SourceCitation(
                    sourceId: (m['sourceId'] as String?) ?? kGrowHowFixtureCitation.sourceId,
                    revision: (m['revision'] as String?) ?? kGrowHowFixtureCitation.revision,
                    passageId: (m['passageId'] as String?) ?? kGrowHowFixtureCitation.passageId,
                    publisher: (m['publisher'] as String?) ?? kGrowHowFixtureCitation.publisher,
                    title: (m['title'] as String?) ?? kGrowHowFixtureCitation.title,
                    canonicalUrl: (m['canonicalUrl'] as String?) ?? kGrowHowFixtureCitation.canonicalUrl,
                  );
                }).toList();

                setState(() {
                  _isStreaming = false;
                  _messages[assistantIdx] = _messages[assistantIdx].copyWith(
                    isStreaming: false,
                    insufficientEvidence: status == 'insufficient_evidence',
                    citations: citations,
                  );
                });
                widget.store.recordChatLog(
                  sessionId: _sessionId,
                  question: trimmed,
                  answer: _messages[assistantIdx].content,
                  dateIso: nowIso.substring(0, 10),
                );
              } else if (ev.event == 'error') {
                final msg = (ev.data['message'] as String?) ?? 'Mentor stream interrupted.';
                setState(() {
                  _isStreaming = false;
                  _messages[assistantIdx] = _messages[assistantIdx].copyWith(
                    isStreaming: false,
                    content: _messages[assistantIdx].content.isEmpty
                        ? 'Unable to complete response: $msg'
                        : _messages[assistantIdx].content,
                  );
                });
              }
            },
            onError: (Object err) {
              if (!mounted) return;
              final fallback = _hasLocalModelDownloaded
                  ? HybridMentorResponder.buildOnDeviceShortAnswer(
                      regionName: region,
                      cropsSummary: cropSummary,
                      userQuestion: trimmed,
                      nextPrepAlert: nextAlert,
                    )
                  : HybridMentorResponder.buildOfflineSafeGuide(
                      regionName: region,
                      cropsSummary: cropSummary,
                      userQuestion: trimmed,
                      nextPrepAlert: nextAlert,
                    );
              setState(() {
                _isStreaming = false;
                _messages[assistantIdx] = _messages[assistantIdx].copyWith(
                  isStreaming: false,
                  modeBadge: fallback.badgeLabel,
                  content: _messages[assistantIdx].content.isEmpty
                      ? fallback.content
                      : _messages[assistantIdx].content,
                );
              });
            },
            onDone: () {
              if (mounted && _isStreaming) {
                setState(() {
                  _isStreaming = false;
                  _messages[assistantIdx] = _messages[assistantIdx].copyWith(isStreaming: false);
                });
              }
            },
          );
      return;
    }

    final aiLogic = widget.store.aiLogic;
    if (aiLogic != null) {
      final aiCropSummary = widget.store.crops.map((c) => '${c.commonName} (${c.growthStage})').join(', ');
      final nextAlertSummary = nextAlert != null
          ? '${nextAlert.cropLabel}: ${nextAlert.title} in ${nextAlert.daysFromToday}d'
          : '';

      setState(() {
        _isStreaming = true;
        _messages.add(_ChatBubble(isUser: true, content: trimmed, timestampIso: nowIso));
        _messages.add(
          _ChatBubble(
            isUser: false,
            content: '',
            timestampIso: nowIso,
            isStreaming: true,
            modeBadge: 'Cloud AI',
          ),
        );
        _draftCtrl.clear();
      });

      final assistantIdx = _messages.length - 1;
      try {
        await for (final chunk in aiLogic.streamMentorReply(
          regionName: region,
          cropsSummary: aiCropSummary.isEmpty ? 'General vegetables' : aiCropSummary,
          plannerSummary: nextAlertSummary,
          userQuestion: trimmed,
        )) {
          if (!mounted) return;
          setState(() {
            _messages[assistantIdx] = _messages[assistantIdx].copyWith(
              content: '${_messages[assistantIdx].content}$chunk',
            );
          });
        }
        if (!mounted) return;
        setState(() {
          _isStreaming = false;
          _messages[assistantIdx] = _messages[assistantIdx].copyWith(isStreaming: false);
        });
        widget.store.recordChatLog(
          sessionId: _sessionId,
          question: trimmed,
          answer: _messages[assistantIdx].content,
          dateIso: nowIso.substring(0, 10),
        );
      } catch (err) {
        if (!mounted) return;
        final fallback = _hasLocalModelDownloaded
            ? HybridMentorResponder.buildOnDeviceShortAnswer(
                regionName: region,
                cropsSummary: cropSummary,
                userQuestion: trimmed,
                nextPrepAlert: nextAlert,
              )
            : HybridMentorResponder.buildOfflineSafeGuide(
                regionName: region,
                cropsSummary: cropSummary,
                userQuestion: trimmed,
                nextPrepAlert: nextAlert,
              );
        setState(() {
          _isStreaming = false;
          _messages[assistantIdx] = _messages[assistantIdx].copyWith(
            isStreaming: false,
            modeBadge: fallback.badgeLabel,
            content: _messages[assistantIdx].content.isEmpty
                ? fallback.content
                : _messages[assistantIdx].content,
          );
        });
      }
      return;
    }

    // Local offline preview fallback when Firebase is not configured
    final hasKnownTopic = RegExp(
      r'\b(water|watering|wilt|pest|aphid|yellow|prune|harvest|soil|mchicha|tomato|okra|fertilizer|dap|urea|npk|foliar|prepare|plan|transplant)\b',
      caseSensitive: false,
    ).hasMatch(trimmed);

    setState(() {
      _messages.add(_ChatBubble(isUser: true, content: trimmed, timestampIso: nowIso));
      if (hasKnownTopic) {
        final plannerLine = nextAlert != null
            ? '\n\nProactive Planner Note: In ${nextAlert.daysFromToday} days (${nextAlert.scheduledDate}), '
                '${nextAlert.cropLabel} is due for "${nextAlert.title}". '
                '${nextAlert.prepReminder ?? ""}'
            : '';
        final replyText =
            'Based on your $region garden (${cropSummary.isEmpty ? "active crops" : cropSummary}): '
            'water early in the morning at the root zone, check leaf undersides twice weekly, '
            'and organize upcoming basal/top-dress inputs ahead of schedule.$plannerLine';
        _messages.add(
          _ChatBubble(
            isUser: false,
            content: replyText,
            timestampIso: nowIso,
            citations: const [kGrowHowFixtureCitation],
          ),
        );
        widget.store.recordChatLog(
          sessionId: _sessionId,
          question: trimmed,
          answer: replyText,
          dateIso: nowIso.substring(0, 10),
        );
      } else {
        _messages.add(
          _ChatBubble(
            isUser: false,
            content:
                'I do not have reviewed horticultural evidence for this specific question in $region. '
                'Please share your crop and visible symptoms or consult your local Tanzanian extension officer.',
            timestampIso: nowIso,
            insufficientEvidence: true,
          ),
        );
      }
      _draftCtrl.clear();
    });
  }

  void _showContextSheet() {
    final plot = widget.store.activePlot;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Garden Context Snapshot', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('As of: ${DateTime.now().toUtc().toIso8601String()}'),
            Text('Mode: ${widget.store.connectionLabel}'),
            const Divider(height: 20),
            Text('Region: ${plot?.regionName ?? "Tanzania"} (TZ)'),
            Text('Plot: ${plot?.name ?? "None"} (${plot?.rainExposure.name ?? "-"})'),
            const SizedBox(height: 8),
            Text('Active Crops: ${widget.store.crops.map((c) => "${c.commonName} (${c.growthStage})").join(", ")}'),
            if (widget.store.computedBatchSchedules.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Planner Countdowns: ${widget.store.computedBatchSchedules.map((s) => "${s.profile.commonName}: ${s.daysToHarvest}d to harvest").join(" • ")}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _archiveSession() async {
    final backend = widget.store.backend;
    if (backend != null) {
      try {
        await backend.archiveChatSession(
          requestId: 'req_arch_${DateTime.now().toUtc().millisecondsSinceEpoch}',
          sessionId: _sessionId,
        );
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Archive sync note: $err')),
          );
        }
      }
    }
    if (mounted) {
      setState(() => _isArchived = true);
    }
  }

  void _confirmArchive() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive conversation?'),
        content: const Text(
          'This hides the conversation from your active list. History is retained until you request account deletion.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(_archiveSession());
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachmentMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Add to Garden Mentor',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo (Camera)'),
              subtitle: const Text('Capture a leaf or plant directly on the farm'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final picked = await pickPlantPhoto(PhotoPickMode.camera);
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TriageFlowScreen(
                      store: widget.store,
                      initialPhoto: picked,
                      initialMode: PhotoPickMode.camera,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Upload Photo from Phone / WhatsApp'),
              subtitle: const Text('Pick a farm photo sent via WhatsApp or saved in gallery'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final picked = await pickPlantPhoto(PhotoPickMode.galleryOrFile);
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TriageFlowScreen(
                      store: widget.store,
                      initialPhoto: picked,
                      initialMode: PhotoPickMode.galleryOrFile,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Find Nearby Agro-Dealer & Price'),
              subtitle: const Text('Call local pembejeo suppliers before travelling'),
              onTap: () {
                Navigator.of(ctx).pop();
                showAgroSupplierSheet(context, store: widget.store);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChatLogsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final logs = widget.store.chatLogs;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved Chat & Search Logs (${logs.length})',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Review past advice, fertilizer notes, and agro-dealer contacts returned by Mentor.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (logs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No saved mentor logs yet. Ask a question to record it here.'),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final entry = logs[idx];
                        return Card(
                          child: ListTile(
                            title: Text(
                              entry.question,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${entry.dateIso} • ${entry.answer}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: 'Delete log',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => widget.store.deleteChatLog(entry.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Garden Mentor'),
        actions: [
          IconButton(
            tooltip: 'Saved Chat & Search Logs',
            icon: const Icon(Icons.history),
            onPressed: _openChatLogsSheet,
          ),
          IconButton(
            tooltip: 'Toggle Offline Simulation',
            icon: Icon(_isOffline ? Icons.wifi_off : Icons.wifi),
            onPressed: () => setState(() => _isOffline = !_isOffline),
          ),
          IconButton(
            tooltip: 'Archive Session',
            icon: const Icon(Icons.archive_outlined),
            onPressed: _messages.isEmpty || _isArchived || _isStreaming ? null : _confirmArchive,
          ),
        ],
      ),
      body: Column(
        children: [
          // Context chip bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                ActionChip(
                  avatar: const BrandLogo(size: 18),
                  label: Text('${widget.store.activePlot?.regionName ?? "Tanzania"} • ${widget.store.crops.length} crops'),
                  onPressed: _showContextSheet,
                ),
                const Spacer(),
                ActionChip(
                  avatar: Icon(
                    _isOffline
                        ? (_hasLocalModelDownloaded ? Icons.memory : Icons.shield_outlined)
                        : Icons.cloud_done_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _isOffline
                        ? (_hasLocalModelDownloaded ? 'On-Device AI' : 'Safe Offline Guide')
                        : (_hasLocalModelDownloaded ? 'Hybrid AI' : 'Cloud AI'),
                  ),
                  backgroundColor: _isOffline && !_hasLocalModelDownloaded
                      ? cs.tertiaryContainer
                      : null,
                  onPressed: () {
                    setState(() => _hasLocalModelDownloaded = !_hasLocalModelDownloaded);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _hasLocalModelDownloaded
                              ? 'On-device local model enabled: short answers work even offline.'
                              : 'Standard device mode: uses Cloud AI online, Safe Guiding Plan offline.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: _isArchived
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Session archived (history retained until account deletion).'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _isArchived = false;
                            _messages.clear();
                            _sessionId = 'sess_${DateTime.now().toUtc().millisecondsSinceEpoch}';
                          }),
                          child: const Text('Start New Session'),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Ask about your Tanzania garden',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          ..._suggestedPrompts.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OutlinedButton(
                                onPressed: () => _sendPrompt(p),
                                child: Align(alignment: Alignment.centerLeft, child: Text(p)),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, idx) {
                          final msg = _messages[idx];
                          return Align(
                            alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Card(
                              color: msg.isUser ? cs.primaryContainer : cs.surfaceContainerHighest,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (msg.modeBadge != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Chip(
                                          visualDensity: VisualDensity.compact,
                                          label: Text(msg.modeBadge!),
                                        ),
                                      ),
                                    if (msg.insufficientEvidence)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 6),
                                        child: Chip(label: Text('Insufficient Reviewed Evidence')),
                                      ),
                                    Text(msg.content.isEmpty && msg.isStreaming ? 'Thinking...' : msg.content),
                                    if (msg.citations.isNotEmpty) ...[
                                      const Divider(height: 14),
                                      ...msg.citations.map(
                                        (c) => Text(
                                          'Source: ${c.publisher} — ${c.title}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                    if (!msg.isUser && !msg.isStreaming && !msg.insufficientEvidence) ...[
                                      const SizedBox(height: 8),
                                      ActionChip(
                                        avatar: const Icon(Icons.storefront_outlined, size: 16),
                                        label: const Text('Find Agro-Dealer & Price'),
                                        onPressed: () => showAgroSupplierSheet(
                                          context,
                                          store: widget.store,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Composer (retains draft while offline) + '+' Attachment button (Camera / WhatsApp Upload / Agro-Dealer)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Add Photo or Tool',
                    onPressed: _openAttachmentMenu,
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _draftCtrl,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: _isOffline ? 'Draft saved offline...' : 'Ask your garden mentor...',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isStreaming ? null : () => _sendPrompt(_draftCtrl.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

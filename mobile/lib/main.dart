import 'dart:async';
import 'package:flutter/material.dart';

import 'data/offline_garden_store.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/crop_planner_screen.dart';
import 'screens/garden_and_mentor_screens.dart';
import 'screens/home_cadence_screen.dart';
import 'screens/mentor_chat_screen.dart';
import 'screens/onboarding_flow.dart';
import 'services/firebase_ai_logic_service.dart';
import 'services/firebase_garden_backend.dart';
import 'services/garden_backend_client.dart';
import 'theme/app_theme.dart';

/// Renders immediately so offline cold starts never block on cloud initialization.
/// Firebase backend & AI Logic attach asynchronously with bounded timeouts.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiGardeningMentorApp());
}

class AiGardeningMentorApp extends StatefulWidget {
  const AiGardeningMentorApp({super.key, this.backend, this.aiLogic});

  final GardenBackendClient? backend;
  final FirebaseAiLogicService? aiLogic;

  @override
  State<AiGardeningMentorApp> createState() => _AiGardeningMentorAppState();
}

class _AiGardeningMentorAppState extends State<AiGardeningMentorApp> {
  late final OfflineGardenStore _store;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _store = OfflineGardenStore(backend: widget.backend, aiLogic: widget.aiLogic);
    if (widget.backend == null && widget.aiLogic == null) {
      unawaited(_attachFirebaseAsync());
    }
  }

  Future<void> _attachFirebaseAsync() async {
    try {
      final initialized = await FirebaseGardenBackend.ensureFirebaseInitialized()
          .timeout(const Duration(seconds: 6), onTimeout: () => false);
      if (!initialized) return;

      final results = await Future.wait<Object?>([
        FirebaseGardenBackend.tryInitialize()
            .timeout(const Duration(seconds: 10), onTimeout: () => null),
        FirebaseAiLogicService.tryInitialize()
            .timeout(const Duration(seconds: 10), onTimeout: () => null),
      ]);
      if (!mounted) return;
      _store.attachServices(
        backend: results[0] as GardenBackendClient?,
        aiLogic: results[1] as FirebaseAiLogicService?,
      );
    } catch (_) {
      // Offline cold start: bundled guides, local auth state, and hybrid adapter stay usable.
    }
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Gardening Mentor',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          if (!_store.isAuthenticated) {
            return AuthGateScreen(store: _store);
          }
          if (!_store.isInitialized) {
            return OnboardingFlow(store: _store);
          }

          return Scaffold(
            body: IndexedStack(
              index: _tabIndex,
              children: [
                HomeCadenceScreen(store: _store),
                CropPlannerScreen(store: _store),
                GardenScreen(store: _store),
                MentorChatScreen(store: _store),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Planner',
                ),
                NavigationDestination(
                  icon: Icon(Icons.yard_outlined),
                  selectedIcon: Icon(Icons.yard),
                  label: 'Garden',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: 'Mentor',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

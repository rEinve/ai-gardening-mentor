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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await FirebaseGardenBackend.tryInitialize();
  final aiLogic = await FirebaseAiLogicService.tryInitialize();
  runApp(AiGardeningMentorApp(backend: backend, aiLogic: aiLogic));
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
                  label: 'Home',
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
                  icon: Icon(Icons.chat_outlined),
                  selectedIcon: Icon(Icons.chat),
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

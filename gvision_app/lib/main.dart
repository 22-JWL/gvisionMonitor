import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/api/api_client.dart';
import 'core/ws/ws_client.dart';
import 'features/home/home_provider.dart';
import 'features/home/home_screen.dart';
import 'features/inspection/inspection_provider.dart';
import 'features/inspection/inspection_screen.dart';
import 'features/events/events_provider.dart';
import 'features/events/events_screen.dart';
import 'features/lots/lots_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/events/event_context_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'services/notification_service.dart';
import 'services/notification_settings.dart';
import 'services/notification_history.dart';
import 'shared/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.loadSettings();
  await NotificationSettings.load();
  await NotificationService.init();
  await NotificationHistory.instance.load();
  runApp(const GVisionApp());
}

class GVisionApp extends StatelessWidget {
  const GVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ws = WsClient()..connect();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WsClient>.value(value: ws),
        ChangeNotifierProvider(create: (_) => HomeProvider(ws)),
        ChangeNotifierProvider(create: (_) => InspectionProvider(ws)),
        ChangeNotifierProvider(create: (_) => EventsProvider(ws)),
        ChangeNotifierProvider<NotificationHistory>.value(
          value: NotificationHistory.instance,
        ),
      ],
      child: MaterialApp(
        title: 'GVision Monitor',
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: const _Shell(),
        onGenerateRoute: (settings) {
          if (settings.name == '/event-context') {
            final id = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => EventContextScreen(eventId: id),
            );
          }
          return null;
        },
      ),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    InspectionScreen(),
    EventsScreen(),
    LotsScreen(),
    NotificationsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.onAlertTapped = (eventId) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventContextScreen(eventId: eventId),
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: '장비 상태',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: '검사 분석',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '이벤트',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Lot 이력',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: '알림',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: '설정',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
        child: const Icon(Icons.settings),
      ),
    );
  }
}

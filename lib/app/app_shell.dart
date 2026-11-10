import 'dart:async';

import 'package:flutter/material.dart';

import '../features/experience/experience.dart';
import '../features/auth/presentation/brand_logo.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.onExitToLogin});
  final VoidCallback? onExitToLogin;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final store = PrayerStore();
  int selected = 0;
  @override
  void initState() {
    super.initState();
    unawaited(store.load());
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.textScalerOf(context).scale(1) * store.textScale,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              BrandLogo(size: 28),
              SizedBox(width: 10),
              Text('아멘모아', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '알림',
              onPressed: () => openPage(context, const NotificationsPage()),
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: [
                HomeScreen(store: store),
                GroupsScreen(store: store),
                PrayerScreen(store: store),
                RecordsScreen(store: store),
                ProfileScreen(
                  store: store,
                  onExitToLogin: widget.onExitToLogin,
                ),
              ][selected],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (value) => setState(() => selected = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              label: '그룹',
            ),
            NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              label: '기도',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: '기록',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: '프로필',
            ),
          ],
        ),
      ),
    ),
  );
}

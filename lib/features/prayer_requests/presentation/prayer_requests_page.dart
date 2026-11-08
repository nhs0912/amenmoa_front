import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

class PrayerRequestsPage extends StatelessWidget {
  const PrayerRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.volunteer_activism_outlined,
      title: '마음을 나눌 기도제목',
      description: '함께 나누는 기도제목이 이곳에 모여요.',
    );
  }
}

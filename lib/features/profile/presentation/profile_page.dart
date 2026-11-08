import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.person_outline,
      title: '평안한 하루 보내세요',
      description: '나의 정보와 기도 기록을 만나는 공간이에요.',
    );
  }
}

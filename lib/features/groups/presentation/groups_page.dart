import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.groups_outlined,
      title: '함께 기도할 모임',
      description: '함께하는 모임이 이곳에 모여요.',
    );
  }
}

import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                radius: 32,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  size: 32,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '오늘도 함께 기도해요',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('작은 기도가 모여 서로에게 힘이 됩니다.', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 32),
            Card.filled(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.favorite_outline, color: colors.primary),
                    const SizedBox(height: 16),
                    Text('기도로 연결되는 하루', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      '모임의 기도제목을 나누고, 서로를 위해 기도하는 공간이에요.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

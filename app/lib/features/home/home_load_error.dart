import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';

/// Shown instead of zeros when 홈 could not load something, so a storage
/// failure never looks like "nothing to review".
class HomeLoadError extends StatelessWidget {
  const HomeLoadError({
    super.key,
    required this.onRetry,
    this.message = '오늘 학습할 단어를 불러오지 못했어요',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: t.riskBg,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: t.risk),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: t.risk, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
        ],
      ),
    );
  }
}

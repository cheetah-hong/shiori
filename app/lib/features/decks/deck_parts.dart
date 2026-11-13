import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori_core/shiori_core.dart';

/// Not the test organizers' list (the official lists are not published).
const deckNotOfficial = '일본어능력시험 주최 측이 낸 목록이 아니에요.';

/// Where the lists come from, under a deck screen's words.
class DeckSourceNote extends StatelessWidget {
  const DeckSourceNote({super.key, required this.sources});

  final List<DeckSource> sources;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final quiet = TextStyle(
      color: t.text3,
      fontSize: TypeScale.small,
      height: 1.45,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '단어 목록 출처',
            style: TextStyle(
              color: t.text2,
              fontSize: TypeScale.small,
              fontWeight: Weights.emphasis,
            ),
          ),
          const SizedBox(height: Space.xs),
          for (final s in sources)
            Text('${s.author}, ${s.name} (${s.license})', style: quiet),
          const SizedBox(height: Space.xs),
          Text('$deckNotOfficial 뜻·예문·발음은 앱의 사전으로 채워요.', style: quiet),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum _LeaderboardRange {
  week('Week'),
  allTime('All-time');

  const _LeaderboardRange(this.label);
  final String label;
}

typedef _Learner = ({
  String avatar,
  String name,
  bool isYou,
  String streak,
  Color rowTint,
});

const _learners = <_Learner>[
  (
    avatar: '🐻',
    name: 'Amira',
    isYou: true,
    streak: '5-day streak · leading the class',
    rowTint: AppColors.goldTint,
  ),
  (
    avatar: '🦁',
    name: 'Zayd',
    isYou: false,
    streak: '4-day streak',
    rowTint: AppColors.mint,
  ),
  (
    avatar: '🐥',
    name: 'Hana',
    isYou: false,
    streak: '4-day streak',
    rowTint: AppColors.goldTint,
  ),
  (
    avatar: '🐢',
    name: 'Yusuf',
    isYou: false,
    streak: '3-day streak',
    rowTint: AppColors.coralTint,
  ),
  (
    avatar: '🐿️',
    name: 'Fatimah',
    isYou: false,
    streak: '2-day streak',
    rowTint: AppColors.mint,
  ),
  (
    avatar: '🦊',
    name: 'Omar',
    isYou: false,
    streak: '1-day streak',
    rowTint: AppColors.goldTint,
  ),
  (
    avatar: '🐸',
    name: 'Layla',
    isYou: false,
    streak: 'No streak yet',
    rowTint: AppColors.coralTint,
  ),
  (
    avatar: '🐨',
    name: 'Bilal',
    isYou: false,
    streak: 'No streak yet',
    rowTint: AppColors.mint,
  ),
];

// Mock points until telemetry lands — same in-memory-only pattern as the
// rest of the Student Hub (FR streak/badge mocks). Keyed by learner name
// so the roster (avatar/streak) stays fixed while the ranking reshuffles
// per range.
const _pointsByRange = {
  _LeaderboardRange.week: {
    'Amira': 248,
    'Zayd': 210,
    'Hana': 192,
    'Yusuf': 176,
    'Fatimah': 164,
    'Omar': 151,
    'Layla': 138,
    'Bilal': 120,
  },
  _LeaderboardRange.allTime: {
    'Zayd': 3120,
    'Amira': 2860,
    'Yusuf': 2490,
    'Hana': 2205,
    'Omar': 1830,
    'Fatimah': 1690,
    'Bilal': 1410,
    'Layla': 1185,
  },
};

/// Own screen (reached from the Student Hub's bottom nav) rather than a
/// section on the hub's home scroll — keeps the hub's first screen short
/// and gives the leaderboard room to grow (class filters, podium, ranked
/// list) without competing for hub scroll space.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  var _range = _LeaderboardRange.week;

  @override
  Widget build(BuildContext context) {
    final points = _pointsByRange[_range]!;
    final ranked = [..._learners]
      ..sort((a, b) => points[b.name]!.compareTo(points[a.name]!));

    final top3 = ranked.take(3).toList();
    final you = ranked.firstWhere((l) => l.isYou);
    final youRank = ranked.indexOf(you) + 1;
    final rest = [
      for (final (i, learner) in ranked.indexed)
        if (i >= 3 && !learner.isYou) (rank: i + 1, learner: learner),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _LeaderboardHeader(
            range: _range,
            onChanged: (r) => setState(() => _range = r),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _Podium(top3: top3, points: points),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: _YouRow(
              learner: you,
              rank: youRank,
              points: points[you.name]!,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Column(
              children: [
                for (final (i, entry) in rest.indexed) ...[
                  if (i > 0) const SizedBox(height: 9),
                  _LeaderboardRow(
                    rank: entry.rank,
                    learner: entry.learner,
                    points: points[entry.learner.name]!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader({required this.range, required this.onChanged});

  final _LeaderboardRange range;
  final ValueChanged<_LeaderboardRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leaderboard',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Class 1-A · ${_learners.length} learners',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _RangeToggle(value: range, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.value, required this.onChanged});

  final _LeaderboardRange value;
  final ValueChanged<_LeaderboardRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.neutralTint,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final range in _LeaderboardRange.values)
            GestureDetector(
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: value == range ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: value == range
                      ? const [
                          BoxShadow(
                            color: Color(0x1F2C2C2A),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  range.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: value == range
                        ? AppColors.teal
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Top-3 podium, centre slot (rank 1) tallest — mirrors the approved mock:
/// rank 1 in the middle with a gold-bordered avatar and the tallest bar,
/// ranks 2/3 flanking it, smaller and silver/plain.
class _Podium extends StatelessWidget {
  const _Podium({required this.top3, required this.points});

  final List<_Learner> top3;
  final Map<String, int> points;

  @override
  Widget build(BuildContext context) {
    final second = top3.length > 1 ? top3[1] : null;
    final first = top3[0];
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (second != null)
            Expanded(
              child: _PodiumSlot(
                learner: second,
                rank: 2,
                points: points[second.name]!,
                avatarSize: 50,
                barHeight: 24,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: _PodiumSlot(
              learner: first,
              rank: 1,
              points: points[first.name]!,
              avatarSize: 64,
              barHeight: 38,
            ),
          ),
          const SizedBox(width: 10),
          if (third != null)
            Expanded(
              child: _PodiumSlot(
                learner: third,
                rank: 3,
                points: points[third.name]!,
                avatarSize: 50,
                barHeight: 14,
              ),
            ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.learner,
    required this.rank,
    required this.points,
    required this.avatarSize,
    required this.barHeight,
  });

  final _Learner learner;
  final int rank;
  final int points;
  final double avatarSize;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: avatarSize,
          height: avatarSize + 10,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFirst
                        ? AppColors.gold
                        : Colors.white.withValues(alpha: .5),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    learner.avatar,
                    style: TextStyle(fontSize: isFirst ? 24 : 19),
                  ),
                ),
              ),
              Positioned(
                bottom: -6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isFirst ? AppColors.gold : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.teal, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isFirst
                            ? const Color(0xFF4A2A00)
                            : AppColors.tealDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          learner.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '$points pts',
          style: TextStyle(
            color: isFirst
                ? AppColors.gold
                : Colors.white.withValues(alpha: .75),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
        ),
      ],
    );
  }
}

class _YouRow extends StatelessWidget {
  const _YouRow({
    required this.learner,
    required this.rank,
    required this.points,
  });

  final _Learner learner;
  final int rank;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A5A10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(learner.avatar, style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        learner.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A2A00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  learner.streak,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A5A10),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$points',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.tealDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.learner,
    required this.points,
  });

  final int rank;
  final _Learner learner;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.creamBorder, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A2C2C2A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: learner.rowTint,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(learner.avatar, style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  learner.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  learner.streak,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$points',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

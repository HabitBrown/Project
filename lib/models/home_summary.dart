// lib/models/home_summary.dart
import 'home_habit.dart';

class HomeSummary {
  final int todayCertCount;
  final int currentDuelCount;
  final int soloHabitCount;

  // 새로 추가: 홈 카드용 리스트들
  final List<HomeHabit> todayHabits;     // 혼자 하는 오늘 습관 (_seedToday 대체)
  final List<HomeHabit> fightingHabits;  // 듀얼/경쟁 습관 (_seedFighting 대체)

  HomeSummary({
    required this.todayCertCount,
    required this.currentDuelCount,
    required this.soloHabitCount,
    required this.todayHabits,
    required this.fightingHabits,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final todayList = (json['today_habits'] as List<dynamic>? ?? [])
        .map((e) => HomeHabit.fromJson(e as Map<String, dynamic>))
        .toList();

    final fightingList = (json['fighting_habits'] as List<dynamic>? ?? [])
        .map((e) => HomeHabit.fromJson(e as Map<String, dynamic>))
        .toList();

    return HomeSummary(
      todayCertCount: json['today_cert_count'] as int,
      currentDuelCount: json['current_duel_count'] as int,
      soloHabitCount: json['solo_habit_count'] as int,
      todayHabits: todayList,
      fightingHabits: fightingList,
    );
  }
}

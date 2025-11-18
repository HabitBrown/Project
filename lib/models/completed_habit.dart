// lib/models/completed_habit.dart

class CompletedHabit {
  final int userHabitId;
  final String title;
  final String method;      // "photo" / "text"
  final int difficulty;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String status;      // "completed_success" / "completed_fail" / "canceled"
  final DateTime? completedAt;

  CompletedHabit({
    required this.userHabitId,
    required this.title,
    required this.method,
    required this.difficulty,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.completedAt,
  });

  factory CompletedHabit.fromJson(Map<String, dynamic> json) {
    return CompletedHabit(
      userHabitId: json['user_habit_id'] as int,
      title: json['title'] as String,
      method: json['method'] as String,
      difficulty: json['difficulty'] as int,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      status: json['status'] as String,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

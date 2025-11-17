// lib/models/home_habit.dart

/// 홈 화면에서 쓰는 습관 상태
enum HabitStatus { pending, verified, skipped }

class HomeHabit {
  final int userHabitId;   // 백엔드 user_habit_id
  final String title;
  final String time;       // "HH:MM까지" 같은 표시용 문자열
  final String method;     // "photo" / "text" (UI에서 "사진"/"텍스트"로 보여줄 수 있음)

  double progress;         // 0.0 ~ 1.0 (지금은 0.0 고정)
  HabitStatus status;      // 클라이언트 전용 상태

  HomeHabit({
    required this.userHabitId,
    required this.title,
    required this.time,
    required this.method,
    this.progress = 0.0,
    this.status = HabitStatus.pending,
  });

  /// 백엔드 `/home/summary` → HomeHabitItemOut JSON 파싱
  factory HomeHabit.fromJson(Map<String, dynamic> json) {
    // deadline_local: "HH:MM:SS" 라고 가정
    final rawDeadline = json['deadline_local'] as String?;
    String displayTime = '';

    if (rawDeadline != null && rawDeadline.length >= 5) {
      final hhmm = rawDeadline.substring(0, 5); // "21:30:00" -> "21:30"
      displayTime = '$hhmm까지';
    }

    final progressNum = (json['progress'] as num?)?.toDouble() ?? 0.0;

    return HomeHabit(
      userHabitId: json['user_habit_id'] as int,
      title: json['title'] as String,
      time: displayTime,
      method: json['method'] as String,
      progress: progressNum,
      status: HabitStatus.pending, // 서버에서 안 내려오므로 기본값
    );
  }
}

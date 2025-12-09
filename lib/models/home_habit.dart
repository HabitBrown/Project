// lib/models/home_habit.dart

/// 홈 화면에서 쓰는 습관 상태
enum HabitStatus { pending, verified, skipped }

class HomeHabit {
  final int userHabitId;   // 백엔드 user_habit_id
  final String title;
  final String time;       // "HH:MM까지" 같은 표시용 문자열
  final String method;     // "photo" / "text"
  final double progress;   // 0.0 ~ 1.0

  // 🔥 여기 추가: 내기 정보
  final int? duelId;         // 이 습관이 연결된 duel id (없으면 null)
  final String? partnerName; // 상대 닉네임 (없으면 null)

  // 이 enum은 홈 DTO 에서는 안 써도 상관 없지만, 기존 코드 유지
  final HabitStatus status;  // 기본은 pending 으로 고정

  HomeHabit({
    required this.userHabitId,
    required this.title,
    required this.time,
    required this.method,
    required this.progress,
    this.duelId,
    this.partnerName,
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

      // 🔥 백엔드 응답에 맞춰서 duel 정보까지 같이 받기
      duelId: json['duel_id'] as int?,                 // ← 응답 키 이름이 duel_id 라고 가정
      partnerName: json['rival_nickname'] as String?,  // ← 응답 키 이름이 rival_nickname 이라고 가정
    );
  }
}

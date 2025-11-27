import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pbl_front/screens/home/home_screen.dart'
    show AppColors, AppImages;

/// =======================
///  SharedPreferences 키
/// =======================
const _kLastDateKey = 'attendance_last_date';
const _kStreakKey = 'attendance_streak';
const _kCheckedTodayKey = 'attendance_checked_today';

// ✅ 이번 7일 사이클의 "시작일" 저장용
const _kCycleStartDateKey = 'attendance_cycle_start_date';

/// =======================
///  전역 상태 (캐시용)
/// =======================

// 마지막으로 출석체크를 시도한 날짜
DateTime? _lastCheckDate;

// 오늘 출석을 이미 했는지
bool _checkedToday = false;

// 연속 출석일 수
int _streak = 0;

/// 홈화면에서 이 함수만 호출하면 됨
///
///   WidgetsBinding.instance.addPostFrameCallback((_) {
///     showDailyCheckDialog(context);
///   });
///
Future<void> showDailyCheckDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 저장된 값 불러오기
  final lastDateStr = prefs.getString(_kLastDateKey);
  _streak = prefs.getInt(_kStreakKey) ?? 0;
  _checkedToday = prefs.getBool(_kCheckedTodayKey) ?? false;

  if (lastDateStr == null) {
    // 첫 실행
    _lastCheckDate = today;
    _checkedToday = false;
    _streak = 0;
  } else {
    final last = DateTime.parse(lastDateStr); // "yyyy-MM-dd" 형태라고 가정

    // 날짜가 바뀌었으면 새로운 하루로 리셋 조건 체크
    if (!_isSameDay(last, today)) {
      final bool wasYesterday = _isYesterday(last, today);

      // 어제가 아니면 -> 끊긴 거니까 streak = 0
      // 어제이긴 한데 이미 7일까지 채웠으면 -> 새 사이클 시작 위해 streak = 0
      if (!wasYesterday || _streak >= 7) {
        _streak = 0;
        // 🔸 필요하면 여기서 사이클 시작일 초기화도 가능
        // await prefs.remove(_kCycleStartDateKey);
      }

      _checkedToday = false;
      _lastCheckDate = today;
    } else {
      _lastCheckDate = last;
    }
  }

  // 계산된 상태를 저장 (오늘 처음 앱을 켠 시점 기준)
  await prefs.setString(_kLastDateKey, _formatDate(today));
  await prefs.setInt(_kStreakKey, _streak);
  await prefs.setBool(_kCheckedTodayKey, _checkedToday);

  // 이미 오늘 출석했으면 팝업 안 띄움 (앱을 다시 켜도 X)
  if (_checkedToday) return;

  // 오늘이 첫 앱 실행 + 아직 출석 안 했을 때만 팝업
  await showDialog(
    context: context,
    barrierDismissible: false, // 바깥 눌러도 안 닫힘 (출석하기 필수)
    builder: (_) {
      return _DailyCheckPopup(
        streak: _streak,
        today: today,
        onAttend: () async {
          // 오늘 출석 처리
          _checkedToday = true;
          _streak += 1;

          // ✅ 이번 7일 사이클의 "1일차"가 되는 순간, 시작일 저장
          // (7일 채우고 다음날 리셋된 뒤, 다시 1일차가 되면 그날로 갱신됨)
          if (_streak == 1) {
            await prefs.setString(
              _kCycleStartDateKey,
              _formatDate(today),
            );
          }

          // 저장
          await prefs.setBool(_kCheckedTodayKey, _checkedToday);
          await prefs.setInt(_kStreakKey, _streak);

          // 7일 연속이면 여기서 나중에 백엔드 호출하면 됨
          if (_streak == 7) {
            // TODO: 백엔드에 "7일 연속 출석 -> 해시 +5 지급" API 호출
            debugPrint('7일 연속 출석! (나중에 서버에서 해시 +5 지급 예정)');
          }
        },
      );
    },
  );
}

/// yyyy-MM-dd 형태로 저장용 포맷
String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

/// =======================
/// 팝업 UI
/// =======================
class _DailyCheckPopup extends StatefulWidget {
  final int streak;
  final DateTime today;
  final Future<void> Function() onAttend;

  const _DailyCheckPopup({
    super.key,
    required this.streak,
    required this.today,
    required this.onAttend,
  });

  @override
  State<_DailyCheckPopup> createState() => _DailyCheckPopupState();
}

class _DailyCheckPopupState extends State<_DailyCheckPopup> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // 화면에서는 "오늘 찍을 칸까지" 보이도록 +1
    final int filledCount = (widget.streak + 1).clamp(1, 7);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFBE7C4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '<  출석체크  >',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              // 상단 설명 줄 (HB 로고 + 텍스트)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(AppImages.hbLogo, width: 32, height: 32),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '연속 7일 출석하시면\n해시재화 +5개를 드려요',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildStampGrid(filledCount),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _pressed
                      ? null
                      : () async {
                    setState(() => _pressed = true);

                    // 오늘 출석까지 포함했을 때 연속 출석 일수
                    final int newStreak = widget.streak + 1;

                    // 이번 사이클의 "딱 7일째"인 경우에만 보상 팝업
                    final bool isSevenDayReward = newStreak == 7;

                    // 전역/저장 상태 갱신
                    await widget.onAttend();

                    // 7일 출석 달성 시 축하 팝업
                    if (isSevenDayReward) {
                      await _showSevenDayRewardDialog(context);
                    }

                    // 마지막에 원래 출석 팝업 닫기
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    '출석하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStampGrid(int count) {
    // 7칸: 오늘 ~ 6일 뒤까지 날짜 표시
    final List<Widget> boxes = List.generate(7, (i) {
      final date = widget.today.add(Duration(days: i));
      final dateLabel =
          '${date.month}/${date.day.toString().padLeft(2, '0')}';

      return _StampBox(
        isFilled: i < count, // 채워진 칸인지
        dateLabel: i < count ? dateLabel : null, // 채워진 칸만 날짜 보여줌
      );
    });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: boxes.sublist(0, 4),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: boxes.sublist(4, 7),
        ),
      ],
    );
  }
}

/// 7일 출석 보상 팝업 (바깥 터치로는 닫히지 않음)
Future<void> _showSevenDayRewardDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false, // 버튼으로만 닫기
    builder: (_) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '7일 출석 완료!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF535353),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '7일간 연속으로 출석하였습니다.\n해시 재화 x5개를 드립니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF535353),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      // TODO: 해시 +5 지급 API 여기서 호출
                      Navigator.pop(context);
                    },
                    child: const Text(
                      '해시재화 5개 받기',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _StampBox extends StatelessWidget {
  final bool isFilled;
  final String? dateLabel;

  const _StampBox({
    required this.isFilled,
    this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 84, // 76 → 84 로 늘려서 overflow 방지
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1C9A4)),
      ),
      alignment: Alignment.center,
      child: isFilled
          ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'lib/assets/image1/attendacne_hash.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 4),
          if (dateLabel != null)
            Text(
              dateLabel!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8C6A3A),
              ),
            ),
        ],
      )
          : const SizedBox.shrink(),
    );
  }
}

/// =======================
/// 날짜 비교 함수
/// =======================
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isYesterday(DateTime last, DateTime now) {
  final la = DateTime(last.year, last.month, last.day);
  final to = DateTime(now.year, now.month, now.day);
  return to.difference(la).inDays == 1;
}

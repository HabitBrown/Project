import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pbl_front/screens/home/home_screen.dart' show AppColors, AppImages;
import 'package:pbl_front/services/attendance_service.dart';

/// =======================
///  SharedPreferences 키 (유저별)
/// =======================
String _lastDateKey(int userId) => 'attendance_last_date_$userId';
String _streakKey(int userId) => 'attendance_streak_$userId';
String _checkedTodayKey(int userId) => 'attendance_checked_today_$userId';
String _cycleStartDateKey(int userId) => 'attendance_cycle_start_date_$userId';

/// =======================
///  전역 상태 (캐시용)
/// =======================

DateTime? _lastCheckDate;   // 마지막 출석 시도 날짜
bool _checkedToday = false; // 오늘 출석 여부
int _streak = 0;            // 연속 출석일 수

/// 홈 화면에서 호출:
/// WidgetsBinding.instance.addPostFrameCallback((_) {
///   showDailyCheckDialog(
///     context,
///     onHbUpdated: (newHb) => setState(() => _hb = newHb),
///   );
/// });
Future<void> showDailyCheckDialog(
    BuildContext context, {
      void Function(int newHb)? onHbUpdated,
    }) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getInt('user_id');
  if (userId == null) return;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 저장된 값 불러오기 (유저별)
  final lastDateStr = prefs.getString(_lastDateKey(userId));
  _streak = prefs.getInt(_streakKey(userId)) ?? 0;
  _checkedToday = prefs.getBool(_checkedTodayKey(userId)) ?? false;

  if (lastDateStr == null) {
    // 첫 실행
    _lastCheckDate = today;
    _checkedToday = false;
    _streak = 0;
  } else {
    final last = DateTime.parse(lastDateStr);

    // 날짜가 바뀌었으면 새로운 하루로 리셋 조건 체크
    if (!_isSameDay(last, today)) {
      final bool wasYesterday = _isYesterday(last, today);

      // 어제가 아니면 -> 끊긴 거니까 streak = 0
      // 어제이긴 한데 이미 7일까지 채웠으면 -> 새 사이클 시작 위해 streak = 0
      if (!wasYesterday || _streak >= 7) {
        _streak = 0;
        // 필요하면 여기서 사이클 시작일 초기화도 가능
        // await prefs.remove(_cycleStartDateKey(userId));
      }

      _checkedToday = false;
      _lastCheckDate = today;
    } else {
      _lastCheckDate = last;
    }
  }

  // 계산된 상태를 저장 (유저별)
  await prefs.setString(_lastDateKey(userId), _formatDate(today));
  await prefs.setInt(_streakKey(userId), _streak);
  await prefs.setBool(_checkedTodayKey(userId), _checkedToday);

  // 이미 오늘 출석했으면 팝업 안 띄움
  if (_checkedToday) return;

  // 오늘 처음 앱 실행 + 아직 출석 안 했을 때만 팝업
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return _DailyCheckPopup(
        streak: _streak,
        today: today,
        onAttend: () async {
          // 오늘 출석 처리 (로컬 기준)
          _checkedToday = true;
          _streak += 1;

          // 이번 7일 사이클의 "1일차"가 되는 순간, 시작일 저장
          if (_streak == 1) {
            await prefs.setString(
              _cycleStartDateKey(userId),
              _formatDate(today),
            );
          }
          await prefs.setBool(_checkedTodayKey(userId), _checkedToday);
          await prefs.setInt(_streakKey(userId), _streak);
        },
        onHbUpdated: onHbUpdated,
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
  final void Function(int newHb)? onHbUpdated;

  const _DailyCheckPopup({
    super.key,
    required this.streak,
    required this.today,
    required this.onAttend,
    this.onHbUpdated,
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
                      '매일 출석 시 해시 +1\n연속 7일 출석하면 +5 추가!',
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

                    // 1) 로컬 출석 상태(streak/checkedToday) 먼저 저장
                    await widget.onAttend();

                    // 2) 서버 출석 체크 (재화 계산 + 반영)
                    final service = AttendanceService();
                    try {
                      final result = await service.checkIn();

                      // 이미 오늘 출석한 상태라면
                      if (result.alreadyChecked) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('오늘은 이미 출석했어요!'),
                            ),
                          );
                        }
                      } else {
                        // 오늘 받은 보상 안내 (기본 1, 7일째면 6)
                        if (result.todayReward > 0 && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '오늘 출석 보상: 해시 ${result.todayReward}개!',
                              ),
                            ),
                          );
                        }

                        // 7일 연속이면 축하 팝업
                        if (result.isSevenDayReward && mounted) {
                          await _showSevenDayRewardDialog(context);
                        }
                      }

                      // HB 숫자 갱신 (홈 상단)
                      if (widget.onHbUpdated != null) {
                        widget.onHbUpdated!(result.hbBalance);
                      }

                      // 마지막에 출석 팝업 닫기
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      // 서버 오류 / 네트워크 문제
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                            Text('출석 처리 중 오류가 발생했어요: $e'),
                          ),
                        );
                      }
                      setState(() => _pressed = false);
                    }
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
                  '7일간 연속으로 출석하였습니다.\n오늘은 해시 재화 6개를 드렸어요!',
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
                      Navigator.pop(context);
                    },
                    child: const Text(
                      '확인',
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
      height: 84,
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
            'lib/assets/image1/attendance_hash.png',
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

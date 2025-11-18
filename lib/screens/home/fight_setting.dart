// lib/screens/home/fight_setting.dart

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'habit_setting.dart' show HabitSetupData, CertType, HabitSetupLogoPath;

/// 교환하기를 눌렀을 때 뜨는 "내기 설정" 페이지
/// pop 할 때 HabitSetupData 를 돌려줌.
class FightSettingPage extends StatefulWidget {
  const FightSettingPage({
    super.key,
    required this.targetTitle,       // 상대 감자의 습관 제목 (예: "아침 6시 기상")
    this.initialDifficulty = 1,      // 원래 난이도(1~5)
    this.initialCertType = CertType.photo,
    this.initialDeadline,            // "21:30" 같은 문자열
  });

  final String targetTitle;
  final int initialDifficulty;
  final CertType initialCertType;
  final String? initialDeadline;

  @override
  State<FightSettingPage> createState() => _FightSettingPageState();
}

class _FightSettingPageState extends State<FightSettingPage> {
  // 요일 선택
  final List<bool> _weekdaySelected = List<bool>.filled(7, false);
  static const _labels = ['월', '화', '수', '목', '금', '토', '일'];

  // 내기할 해시 재화 개수(= 상대가 설정한 난이도, 고정)
  late final int _difficulty;

  // 인증 방식 (표시만, 수정 불가)
  late final CertType _certType;

  // 인증마감 시간
  final TextEditingController _hourCtrl = TextEditingController();
  final TextEditingController _minuteCtrl = TextEditingController();
  bool _isAm = true;      // true = 오전, false = 오후
  bool _todayOnly = false; // "하루 안에 인증하기"

  @override
  void initState() {
    super.initState();

    // 원래 난이도(1~5로 클램프) -> 그대로 사용 (고정)
    _difficulty = widget.initialDifficulty.clamp(1, 5);

    // 인증방식 초기값 (표시만, 수정 불가)
    _certType = widget.initialCertType;

    // 마감시간 초기값 파싱 (HabitSetupPage와 동일 로직)
    final parsed = _parseDeadline(widget.initialDeadline ?? '');
    _hourCtrl.text = parsed.$1;
    _minuteCtrl.text = parsed.$2;
    _isAm = parsed.$3;
  }

  // "21:30" -> ("09","30",false)
  (String, String, bool) _parseDeadline(String input) {
    if (input.isEmpty) {
      return ('09', '00', true);
    }
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(input);
    if (m == null) return ('09', '00', true);
    int hh = int.parse(m.group(1)!);
    final mm = m.group(2)!;
    bool am;
    if (hh == 0) {
      hh = 12;
      am = true;
    } else if (hh == 12) {
      am = false;
    } else if (hh > 12) {
      hh -= 12;
      am = false;
    } else {
      am = true;
    }
    return (hh.toString().padLeft(2, '0'), mm, am);
  }

  bool _isValidHourMinute(String h, String m) {
    final hh = int.tryParse(h);
    final mm = int.tryParse(m);
    if (hh == null || mm == null) return false;
    if (hh < 1 || hh > 12) return false;
    if (mm < 0 || mm > 59) return false;
    return true;
  }

  String _build24hTime(String h, String m, bool am) {
    int hh = int.parse(h);
    final mm = int.parse(m);
    if (am) {
      if (hh == 12) hh = 0;
    } else {
      if (hh != 12) hh += 12;
    }
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  void _showSnack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _toggleDay(int i) {
    setState(() => _weekdaySelected[i] = !_weekdaySelected[i]);
  }

  void _submit() {
    // 요일 검증
    final days = <int>[];
    for (int i = 0; i < 7; i++) {
      if (_weekdaySelected[i]) days.add(i + 1);
    }
    // 주 3회 미만이면 내기 불가
    if (days.length < 3) {
      _showSnack('요일은 최소 3개 이상 선택해 주세요.');
      return;
    }

    // 인증마감시간 검증
    String deadline24;
    if (_todayOnly) {
      deadline24 = '23:59';
    } else {
      final hourText = _hourCtrl.text.trim();
      final minuteText = _minuteCtrl.text.trim();
      if (hourText.isEmpty || minuteText.isEmpty) {
        _showSnack('인증 마감 시간을 입력해 주세요.');
        return;
      }
      if (!_isValidHourMinute(hourText, minuteText)) {
        _showSnack('시간은 시(1~12) / 분(0~59)으로 입력해 주세요.');
        return;
      }
      deadline24 = _build24hTime(hourText, minuteText, _isAm);
    }

    // 싸우기 기간: 오늘부터 한 달 (28일)로 고정
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 27));

    final result = HabitSetupData(
      title: widget.targetTitle, // 상대 습관 제목을 그대로 사용
      startDate: start,
      endDate: end,
      weekdays: days,
      difficulty: _difficulty,   // 고정
      certType: _certType,       // 원래 인증 방식
      deadline: deadline24,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8EEDD),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 뒤로가기
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: AppColors.brick,
                    ),
                    label: const Text(
                      '뒤로가기',
                      style: TextStyle(fontSize: 12, color: AppColors.brick),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 감자 + 타이틀
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        HabitSetupLogoPath,
                        width: 90,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '내기 설정 하기',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brick,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 습관 이름 (왼쪽 정렬 + 검은색 + 밑줄)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.targetTitle,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 1.6,
                        width: double.infinity,
                        color: AppColors.brick,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  // · 기간 : 해시내기 기간은 한 달로 fix 됩니다!
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Text('· ', style: TextStyle(fontSize: 16)),
                      Text(
                        '기간 : ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.info_outline, size: 14, color: Colors.black45),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '해시내기 기간은 한 달로 fix 됩니다!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 요일 선택
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(
                      7,
                          (i) => _DayChip(
                        label: _labels[i],
                        selected: _weekdaySelected[i],
                        onTap: () => _toggleDay(i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 내기할 해시 재화 갯수 (고정 값만 표시)
                  Row(
                    children: [
                      const Text('· ', style: TextStyle(fontSize: 16)),
                      const Text(
                        '내기할 해시재화 갯수',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              content: const Text(
                                '상대가 설정해둔 난이도를 기준으로, 해당 값만큼 해시 재화를 걸고 내기하게 됩니다.',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey, width: 1),
                          ),
                          child: const Icon(
                            Icons.question_mark,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 해시 아이콘 5칸 + 텍스트 (네모칸 안에 해시)
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (i) {
                          final filled = i < _difficulty;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE0D0BE),
                                  width: 1.4,
                                ),
                              ),
                              child: filled
                                  ? Padding(
                                padding: const EdgeInsets.all(3),
                                child: Image.asset(
                                  'lib/assets/image1/level_hash.png',
                                  fit: BoxFit.contain,
                                ),
                              )
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '해시 $_difficulty개',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 인증 방식 (표시만, 수정 불가)
                  const _SectionLabel('인증 방식'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CertTypePill(
                        label: '사진',
                        selected: _certType == CertType.photo,
                      ),
                      const SizedBox(width: 8),
                      _CertTypePill(
                        label: '글',
                        selected: _certType == CertType.text,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 인증마감 시간
                  const _SectionLabel('인증마감 시간'),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _todayOnly,
                        onChanged: (v) {
                          setState(() {
                            _todayOnly = v ?? false;
                          });
                        },
                        activeColor: AppColors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const Text(
                        '하루 안에 인증하기',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '인증마감 시간을 넘기면 인증이 불가합니다.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      ToggleButtons(
                        isSelected: _todayOnly
                            ? const [false, false]
                            : [_isAm, !_isAm],
                        onPressed: _todayOnly
                            ? null
                            : (i) {
                          setState(() {
                            _isAm = (i == 0);
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        constraints: const BoxConstraints(
                          minHeight: 40,
                          minWidth: 50,
                        ),
                        fillColor: AppColors.green,
                        selectedColor: Colors.white,
                        color: AppColors.dark,
                        children: const [
                          Text(
                            '오전',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '오후',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      // 시
                      SizedBox(
                        width: 60,
                        child: TextField(
                          enabled: !_todayOnly,
                          controller: _hourCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '시',
                            filled: true,
                            fillColor:
                            _todayOnly ? Colors.grey.shade200 : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide:
                              BorderSide(color: AppColors.divider),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.brick),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        ':',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 분
                      SizedBox(
                        width: 60,
                        child: TextField(
                          enabled: !_todayOnly,
                          controller: _minuteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '분',
                            filled: true,
                            fillColor:
                            _todayOnly ? Colors.grey.shade200 : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide:
                              BorderSide(color: AppColors.divider),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.brick),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 안내 문구 + 버튼
                  const SizedBox(height: 28),
                  const Center(
                    child: Text(
                      '내기할 해시재화 갯수와 인증 방식은\n'
                          '상대가 설정한 값으로 고정되며 수정할 수 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDB6D6D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: _submit,
                        child: const Text(
                          '싸우자!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 공통 섹션 라벨 (· 제목)
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          const Text('· ', style: TextStyle(fontSize: 16)),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// 요일 칩
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE7C7B0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF7D6B60),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 인증 방식 표시용 칩 (수정 불가)
class _CertTypePill extends StatelessWidget {
  const _CertTypePill({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72, minHeight: 36),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.green : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.green : AppColors.divider,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: selected ? Colors.white : AppColors.dark,
        ),
      ),
    );
  }
}

// lib/screens/home/habit_setting.dart

import 'package:flutter/material.dart';
import '../../models/farmer.dart';
import 'home_screen.dart';  // ✅ AppColors 가져오기

/// 백엔드에 던지기 쉽게 만들어둔 DTO
class HabitSetupData {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<int> weekdays;
  final int difficulty;      // ✅ 난이도
  final CertType certType;
  final String deadline;

  HabitSetupData({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.weekdays,
    required this.difficulty,   // ✅ required
    required this.certType,
    required this.deadline,
  });
}

const HabitSetupLogoPath = 'lib/assets/image2/habit_setting_icon.png';

class HabitSetupPage extends StatefulWidget {
  const HabitSetupPage({
    super.key,
    this.initialTitle = '습관을 설정해주세요',
    this.initialStartDate,
    this.initialEndDate,
    this.initialWeekdays,
    this.initialBet,    // 예: "해시 3개" → 난이도 초기값으로 사용
    this.initialCertType = CertType.photo,
    this.initialDeadline, // "21:30"
  });

  final String initialTitle;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final List<int>? initialWeekdays;
  final String? initialBet;
  final CertType initialCertType;
  final String? initialDeadline;

  @override
  State<HabitSetupPage> createState() => _HabitSetupPageState();
}

class _HabitSetupPageState extends State<HabitSetupPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;

  bool _showTitleHint = true;
  bool _isAm = true;
  bool _todayOnly = false;

  DateTimeRange? _selectedRange;
  final List<bool> _weekdaySelected = List<bool>.filled(7, false);

  // 난이도(1~5)
  int _difficulty = 1;

  CertType _certType = CertType.photo;

  static const _labels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();

    // 제목
    final hasInitialTitle =
        widget.initialTitle != '습관을 설정해주세요' &&
            widget.initialTitle.trim().isNotEmpty;
    _showTitleHint = !hasInitialTitle;
    _titleCtrl = TextEditingController(
      text: hasInitialTitle ? widget.initialTitle : '',
    );

    // 기간
    final now = DateTime.now();
    final start =
        widget.initialStartDate ?? DateTime(now.year, now.month, now.day);
    final end = widget.initialEndDate ?? start.add(const Duration(days: 27));
    _selectedRange = DateTimeRange(start: start, end: end);

    // 요일
    if (widget.initialWeekdays != null) {
      for (final d in widget.initialWeekdays!) {
        if (d >= 1 && d <= 7) _weekdaySelected[d - 1] = true;
      }
    }

    // initialBet에서 숫자만 뽑아서 난이도 초기값으로 사용 (1~5 범위에서만)
    final fromBet = _extractHashCount(widget.initialBet);
    if (fromBet >= 1 && fromBet <= 5) {
      _difficulty = fromBet;
    } else {
      _difficulty = 1;
    }

    // 인증 방식
    _certType = widget.initialCertType;

    // 시간
    final parsed = _parseDeadline(widget.initialDeadline ?? '');
    _hourCtrl = TextEditingController(text: parsed.$1);
    _minuteCtrl = TextEditingController(text: parsed.$2);
    _isAm = parsed.$3;
  }

  // "해시 5개" -> 5
  int _extractHashCount(String? label) {
    if (label == null) return 0;
    final m = RegExp(r'\d+').firstMatch(label);
    if (m == null) return 0;
    return int.tryParse(m.group(0)!) ?? 0;
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

  void _toggleDay(int i) =>
      setState(() => _weekdaySelected[i] = !_weekdaySelected[i]);

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // 요일
    final selectedDays = <int>[];
    for (int i = 0; i < 7; i++) {
      if (_weekdaySelected[i]) selectedDays.add(i + 1);
    }
    if (selectedDays.isEmpty) {
      _showSnack('요일을 한 개 이상 선택해 주세요.');
      return;
    }

    // (필요하면 나중에 사용) 난이도(1~5) -> 해시 개수
    // final betLabel = _difficulty.clamp(1, 5);

    // 시간
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

    final result = HabitSetupData(
      title: _titleCtrl.text.trim(),
      startDate: _selectedRange!.start,
      endDate: _selectedRange!.end,
      weekdays: selectedDays,
      difficulty: _difficulty,
      certType: _certType,
      deadline: deadline24,
    );

    Navigator.of(context).pop<HabitSetupData>(result);
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

  void _showSnack(String m) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8EEDD),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              // ✅ 가로 너비 줄이기: 좌우 여백 더 줌
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 뒤로가기
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: AppColors.brick,
                      ),
                      label: const Text(
                        '뒤로가기',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.brick),
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
                          '습관 설정 하기',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brick,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),

                    // 제목
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextFormField(
                        controller: _titleCtrl,
                        decoration: InputDecoration(
                          hintText: _showTitleHint
                              ? '예) 아침에 물 마시기'
                              : null,
                          hintStyle: const TextStyle(
                              color: Colors.black38),
                          filled: true,
                          fillColor: const Color(0xFFF8EEDD),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide:
                            BorderSide(color: AppColors.brick),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFFDB6D6D),
                              width: 1.5,
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        onTap: () {
                          if (_showTitleHint) {
                            setState(() => _showTitleHint = false);
                          }
                        },
                        onChanged: (v) {
                          if (v.isEmpty && !_showTitleHint) {
                            setState(() => _showTitleHint = true);
                          } else if (v.isNotEmpty && _showTitleHint) {
                            setState(() => _showTitleHint = false);
                          }
                        },
                        validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? '제목을 입력해 주세요.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 기간
                    const _SectionLabel('기간'),
                    _DateRangeField(
                      range: _selectedRange,
                      onPick: () async {
                        final now = DateTime.now();
                        final first =
                        DateTime(now.year - 1, 1, 1);
                        final last =
                        DateTime(now.year + 2, 12, 31);

                        const pickerColor = Color(0xFFECCA89);

                        final picked =
                        await showDateRangePicker(
                          context: context,
                          firstDate: first,
                          lastDate: last,
                          initialDateRange: _selectedRange,
                          builder: (context, child) {
                            final theme = Theme.of(context);
                            return Theme(
                              data: theme.copyWith(
                                colorScheme:
                                theme.colorScheme.copyWith(
                                  primary: pickerColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                ),
                                datePickerTheme:
                                DatePickerThemeData(
                                  rangeSelectionBackgroundColor:
                                  pickerColor
                                      .withOpacity(0.35),
                                  dayOverlayColor:
                                  MaterialStateProperty.all(
                                    pickerColor
                                        .withOpacity(0.15),
                                  ),
                                  rangeSelectionOverlayColor:
                                  MaterialStateProperty.all(
                                    pickerColor
                                        .withOpacity(0.1),
                                  ),
                                ),
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                  const BoxConstraints(
                                      maxWidth: 340),
                                  child: Material(
                                    color: Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(
                                        16),
                                    clipBehavior:
                                    Clip.antiAlias,
                                    child: child,
                                  ),
                                ),
                              ),
                            );
                          },
                        );

                        if (picked != null) {
                          setState(() {
                            _selectedRange =
                                DateTimeRange(
                                  start: DateTime(
                                    picked.start.year,
                                    picked.start.month,
                                    picked.start.day,
                                  ),
                                  end: DateTime(
                                    picked.end.year,
                                    picked.end.month,
                                    picked.end.day,
                                  ),
                                );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // 요일
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

                    // 난이도 섹션
                    Row(
                      children: [
                        const Text('· ', style: TextStyle(fontSize: 16)),
                        const Text(
                          '난이도',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // ❓ 물음표 아이콘
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                content: const Text(
                                  '해시내기에서 내기에 사용될 기준 해시재화 갯수로 설정될 예정입니다.',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.grey, width: 1),
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
                    Row(
                      children: List.generate(5, (i) {
                        final level = i + 1;
                        final selected = _difficulty == level;
                        return Padding(
                          padding:
                          const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _difficulty = level);
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.green
                                    : Colors.white,
                                borderRadius:
                                BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.green
                                      : const Color(0xFFE7C7B0),
                                ),
                              ),
                              child: Text(
                                '$level',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF7D6B60),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // 인증 방식
                    const _SectionLabel('인증 방식'),
                    const SizedBox(height: 8),
                    ToggleButtons(
                      isSelected: [
                        _certType == CertType.photo,
                        _certType == CertType.text,
                      ],
                      onPressed: (i) => setState(
                            () => _certType = i == 0
                            ? CertType.photo
                            : CertType.text,
                      ),
                      borderRadius:
                      BorderRadius.circular(10),
                      constraints: const BoxConstraints(
                          minHeight: 44, minWidth: 72),
                      fillColor: AppColors.green,
                      selectedColor: Colors.white,
                      color: AppColors.dark,
                      children: const [
                        Text(
                          '사진',
                          style: TextStyle(
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '글',
                          style: TextStyle(
                              fontWeight: FontWeight.w500),
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
                            borderRadius:
                            BorderRadius.circular(6),
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
                          borderRadius:
                          BorderRadius.circular(10),
                          constraints:
                          const BoxConstraints(
                            minHeight: 40,
                            minWidth: 50,
                          ),
                          fillColor: AppColors.green,
                          selectedColor: Colors.white,
                          color: AppColors.dark,
                          children: const [
                            Text(
                              '오전',
                              style: TextStyle(
                                  fontWeight:
                                  FontWeight.w500),
                            ),
                            Text(
                              '오후',
                              style: TextStyle(
                                  fontWeight:
                                  FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        // 시
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            enabled: !_todayOnly,
                            controller: _hourCtrl,
                            keyboardType:
                            TextInputType.number,
                            decoration:
                            InputDecoration(
                              hintText: '시',
                              filled: true,
                              fillColor: _todayOnly
                                  ? Colors.grey.shade200
                                  : Colors.white,
                              contentPadding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              enabledBorder:
                              const OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: AppColors
                                        .divider),
                              ),
                              focusedBorder:
                              const OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: AppColors.brick),
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
                          child: TextFormField(
                            enabled: !_todayOnly,
                            controller: _minuteCtrl,
                            keyboardType:
                            TextInputType.number,
                            decoration:
                            InputDecoration(
                              hintText: '분',
                              filled: true,
                              fillColor: _todayOnly
                                  ? Colors.grey.shade200
                                  : Colors.white,
                              contentPadding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              enabledBorder:
                              const OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: AppColors
                                        .divider),
                              ),
                              focusedBorder:
                              const OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: AppColors.brick),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 42),

                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 48,
                        child: ElevatedButton(
                          style:
                          ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFFDB6D6D),
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  28),
                            ),
                          ),
                          onPressed: _submit,
                          child: const Text(
                            '도전하기!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                              FontWeight.w700,
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
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding:
    const EdgeInsets.only(top: 8, bottom: 6),
    child: Row(
      children: [
        const Text('· ',
            style: TextStyle(fontSize: 16)),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : const Color(0xFFE7C7B0),
          ),
          // ✅ 번지는 효과(그림자) 제거
          // boxShadow: [] 로 두거나 아예 속성 제거
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : const Color(0xFF7D6B60),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.range,
    required this.onPick,
  });
  final DateTimeRange? range;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasValue = range != null;
    final text = hasValue
        ? '${_fmt(range!.start)} ~ ${_fmt(range!.end)}'
        : '달력에서 기간을 선택하세요';
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(
            horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFFE7C7B0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: hasValue
                      ? Colors.black87
                      : Colors.black45,
                  fontSize: 16,
                  fontWeight: hasValue
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

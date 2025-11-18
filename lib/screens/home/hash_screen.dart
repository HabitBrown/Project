import 'package:flutter/material.dart';
import 'fight_setting.dart'; // ✅ 내기 설정 화면
import 'home_screen.dart' show AppImages, AppColors;

/// =======================
/// 이미지 경로
/// =======================
const String _assetRoot = 'lib/assets/image1';
const String _logoPath   = '$_assetRoot/small_habit_logo.png';
const String _hbPath     = '$_assetRoot/HB_logo.png';
const String _cartPath   = '$_assetRoot/cart.png';
const String _fightImage = '$_assetRoot/potato_fight.png';

// 싸우는 감자 카드 배경 (노란+주황 막대 이미지)
const String _rivalBg = '$_assetRoot/fighting_gamja.png';

/// =======================
/// 색
/// =======================
const Color kPageBg        = Colors.white;      // 위쪽 전체 배경
const Color kBelowFighting = Color(0xFFFFF9ED); // 싸우고 있는 감자 패널 배경 (연한 베이지)
const Color kHeaderBrown   = Color(0xFFBF8D6A); // 해시내기 헤더
const Color kChallengeChip = Color(0xFFFDF3D9);

/// =======================
/// 간단 DTO들
/// =======================

class ChallengeInfo {
  final String farmerName;
  final String title;

  const ChallengeInfo({
    required this.farmerName,
    required this.title,
  });
}

class RivalInfo {
  final String name;
  final int days;     // 예: 30
  final String habit; // 예: '코딩 테스트 하기'
  final bool showRightButton;

  const RivalInfo({
    required this.name,
    required this.days,
    required this.habit,
    this.showRightButton = true,
  });
}

/// =======================
/// 해시내기 화면
/// =======================
class HashScreen extends StatefulWidget {
  const HashScreen({
    super.key,
    required this.hbCount,
    this.onHbChanged,
  });

  final int hbCount;
  final ValueChanged<int>? onHbChanged;

  @override
  State<HashScreen> createState() => _HashScreenState();
}

class _HashScreenState extends State<HashScreen> {
  late int _currentHb;

  /// 도전장 목록 (거절하면 여기서 제거)
  late List<ChallengeInfo> _challenges;

  final List<RivalInfo> _rivals = const [
    RivalInfo(name: '송강호', days: 30, habit: '코딩 테스트 하기'),
    RivalInfo(name: '유민재', days: 25, habit: '야채 먹기'),
    RivalInfo(name: '이연제', days: 18, habit: '러닝 3km'),
    RivalInfo(name: '러너핑', days: 8, habit: '러닝 3km'),
  ];

  @override
  void initState() {
    super.initState();
    _currentHb = widget.hbCount;

    _challenges = [
      const ChallengeInfo(
        farmerName: '이연제',
        title: '하루에 한잔 물 마시기',
      ),
      const ChallengeInfo(
        farmerName: '유민재',
        title: '나의 습관 1개',
      ),
    ];
  }

  /// 확인해보기 눌렀을 때 아래 패널 띄우기
  void _onCheckChallenge(ChallengeInfo info) {
    final int idx = _challenges.indexOf(info);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ChallengeDetailSheet(
          info: info,
          // ✅ 수락: 선택한 습관 데이터를 받아서 내기 설정 화면으로 이동
          onAccept: (selectedHash) async {
            // 1) 바텀시트 닫기
            Navigator.of(ctx).pop();

            // 2) 선택한 습관 정보로 FightSettingPage 열기
            final String habitTitle =
                selectedHash['title']?.toString() ?? info.title;
            final int difficulty =
                (selectedHash['difficulty'] as int?) ?? 1;

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FightSettingPage(
                  targetTitle: habitTitle,
                  initialDifficulty: difficulty,
                ),
              ),
            );
          },
          onReject: () {
            // ‘거절’ 버튼을 직접 눌렀을 때만 도전장 삭제
            Navigator.of(ctx).pop();
            setState(() {
              if (idx >= 0 && idx < _challenges.length) {
                _challenges.removeAt(idx);
              }
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 0)),
              SliverToBoxAdapter(
                child: _HashTopBar(hbCount: _currentHb),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: kPageBg,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _HashHeader(),
                      const SizedBox(height: 20),
                      _ChallengeList(
                        items: _challenges,
                        onCheck: _onCheckChallenge,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _RivalSection(rivals: _rivals),
              ),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(color: kBelowFighting),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _HashBottomBar(
        index: 1,
        onChanged: (i) {
          if (i == 0) {
            // 감자캐기
            Navigator.pushReplacementNamed(
              context,
              '/potato',
              arguments: {'hbCount': _currentHb},
            );
          } else if (i == 1) {
            // 해시내기(현재 화면) → 아무것도 안 함
          } else if (i == 2) {
            // 홈화면으로 이동
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
                  (route) => false,
            );
          } else if (i == 3) {
            // TODO: 알림 화면 연결
          } else if (i == 4) {
            // ✅ 마이페이지 이동
            Navigator.pushReplacementNamed(
              context,
              '/mypage',
              arguments: {'hbCount': _currentHb},
            );
          }
        },
      ),
    );
  }
}

/// =======================
/// 상단 AppBar
/// =======================
class _HashTopBar extends StatelessWidget implements PreferredSizeWidget {
  final int hbCount;
  const _HashTopBar({required this.hbCount});

  @override
  Size get preferredSize => const Size.fromHeight(92);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 84,
      leadingWidth: 140,
      leading: Padding(
        padding: const EdgeInsets.only(left: 6, top: 10),
        child: GestureDetector(
          onTap: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
                  (route) => false,
            );
          },
          child: Image.asset(
            _logoPath,
            width: 94,
            height: 18,
            fit: BoxFit.contain,
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF6E08F),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE2B65A), width: 1),
          ),
          child: Row(
            children: [
              Image.asset(_hbPath, width: 20, height: 20),
              const SizedBox(width: 6),
              Text(
                '$hbCount',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: Image.asset(_cartPath, width: 22, height: 22),
          onPressed: () {},
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

/// =======================
/// 해시내기 헤더
/// =======================
class _HashHeader extends StatelessWidget {
  const _HashHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: kHeaderBrown,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 2),
            child: Image.asset(
              _fightImage,
              width: 82,
              height: 74,
              fit: BoxFit.contain,
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '해시내기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '누가 튀겨질 것인가...!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// =======================
/// 도전장 목록
/// =======================
class _ChallengeList extends StatelessWidget {
  const _ChallengeList({
    required this.items,
    this.onCheck,
  });

  final List<ChallengeInfo> items;
  final ValueChanged<ChallengeInfo>? onCheck;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '다른 농부가 보낸 도전장이 없습니다.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _ChallengeRow(
            farmerName: items[i].farmerName,
            title: items[i].title,
            onCheck: () => onCheck?.call(items[i]),
          ),
          if (i != items.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  final String farmerName;
  final String title;
  final VoidCallback? onCheck;

  const _ChallengeRow({
    required this.farmerName,
    required this.title,
    this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double maxRowWidth = 325.0;
        final double rowWidth =
        constraints.maxWidth > maxRowWidth ? maxRowWidth : constraints.maxWidth;

        // 프로필(38) + 간격(10) 제외한 내용 폭
        final double contentWidth = rowWidth - 48;

        const double chipBaseWidth = 240.0;
        final double chipWidth =
        contentWidth < chipBaseWidth ? contentWidth : chipBaseWidth;

        final String fromText = '$farmerName 농부가 도전장을 보냈습니다.';

        return Center(
          child: SizedBox(
            width: rowWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFD9D9D9),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fromText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: chipWidth,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kChallengeChip,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '· $title',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: contentWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 25),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: onCheck,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5D58C),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '확인해보기',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// =======================
/// 확인해보기 바텀시트
/// =======================

class _ChallengeDetailSheet extends StatefulWidget {
  final ChallengeInfo info;
  final void Function(Map<String, dynamic> selectedHash) onAccept; // ✅ 선택된 습관 전달
  final VoidCallback onReject;

  const _ChallengeDetailSheet({
    required this.info,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_ChallengeDetailSheet> createState() => _ChallengeDetailSheetState();
}

class _ChallengeDetailSheetState extends State<_ChallengeDetailSheet> {
  int? _selectedIndex; // 하나만 선택

  bool get _canAccept => _selectedIndex != null;

  @override
  Widget build(BuildContext context) {
    // 예시용 데이터 (나중에 B 농부의 해시 목록으로 교체)
    final List<Map<String, dynamic>> dummyHashes = [
      {
        'title': '말해보기 하기',
        'difficulty': 3,
      },
      {
        'title': '${widget.info.farmerName}가 가진 습관 2',
        'difficulty': 4,
      },
      {
        'title': '${widget.info.farmerName}가 가진 습관 3',
        'difficulty': 5,
      },
    ];

    return GestureDetector(
      // 바깥(어두운 부분)을 탭하면 닫기
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
      },
      child: Container(
        color: Colors.black.withOpacity(0.15),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {},
                child: Material(
                  borderRadius: BorderRadius.circular(26),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    color: const Color(0xFFFFF8D2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${widget.info.farmerName} 농부가 도전장을 보냈습니다.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1CB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '· ${widget.info.title}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '내가 선택할 ${widget.info.farmerName} 농부의 습관',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E2A5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                          child: Column(
                            children: [
                              for (int i = 0; i < dummyHashes.length; i++) ...[
                                _ChallengeDetailRow(
                                  title: dummyHashes[i]['title'] as String,
                                  difficulty:
                                  dummyHashes[i]['difficulty'] as int,
                                  selected: _selectedIndex == i,
                                  onSelect: () {
                                    setState(() {
                                      _selectedIndex = i;
                                    });
                                  },
                                ),
                                if (i != dummyHashes.length - 1)
                                  const SizedBox(height: 6),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 34,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _canAccept
                                        ? const Color(0xFFF1CC4D)
                                        : const Color(0xFFE5DFBF),
                                    foregroundColor: Colors.black87,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: _canAccept
                                      ? () {
                                    final selected =
                                    dummyHashes[_selectedIndex!];
                                    widget.onAccept(selected);
                                  }
                                      : null,
                                  child: const Text(
                                    '수락',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 34,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    const Color(0xFFE4D6A7),
                                    foregroundColor: Colors.black87,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: widget.onReject,
                                  child: const Text(
                                    '거절',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 한 줄 (· 제목 + 난이도칩 + 선택 버튼)
class _ChallengeDetailRow extends StatelessWidget {
  final String title;
  final int difficulty;
  final bool selected;
  final VoidCallback onSelect;

  const _ChallengeDetailRow({
    required this.title,
    required this.difficulty,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 텍스트 + 난이도칩 묶음
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 2,
            spacing: 6,
            children: [
              Text(
                '· $title',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFAFDBAE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '난이도: $difficulty',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Image.asset(
                      '$_assetRoot/level_hash.png',
                      width: 13,
                      height: 13,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 26,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: Color(0xFFE07554),
                width: 1.2,
              ),
              backgroundColor: selected
                  ? const Color(0xFFE07554)
                  : const Color(0xFFFBE0C7),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onSelect,
            child: Text(
              '선택',
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white : const Color(0xFFBB3A27),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// =======================
/// 싸우고 있는 감자 영역
/// =======================
class _RivalSection extends StatelessWidget {
  const _RivalSection({super.key, required this.rivals});

  final List<RivalInfo> rivals;

  @override
  Widget build(BuildContext context) {
    const double labelHeight = 40;
    const double panelRadius = 18;
    const borderColor = Color(0xFFE3D3B8);

    return Container(
      color: kPageBg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 35),
            decoration: BoxDecoration(
              color: kBelowFighting,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(panelRadius),
                topRight: Radius.circular(panelRadius),
              ),
              border: const Border(
                top: BorderSide(color: borderColor, width: 1),
                left: BorderSide(color: borderColor, width: 1),
                right: BorderSide(color: borderColor, width: 1),
                bottom: BorderSide.none,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 38, 8, 18),
              child: rivals.isEmpty
                  ? SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    '현재 싸우고 있는 감자가 없습니다.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ),
              )
                  : Column(
                children: [
                  for (int i = 0; i < rivals.length; i++) ...[
                    _RivalCard(
                      name: rivals[i].name,
                      days: rivals[i].days,
                      habit: rivals[i].habit,
                      showRightButton: rivals[i].showRightButton,
                    ),
                    if (i != rivals.length - 1)
                      const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 30,
            top: 12,
            child: Container(
              height: labelHeight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF2C94C),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
              ),
              child: const Text(
                '싸우고 있는 감자',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// 라이벌 카드
/// =======================
class _RivalCard extends StatelessWidget {
  final String name;
  final int days;
  final String habit;
  final bool showRightButton;

  const _RivalCard({
    required this.name,
    required this.days,
    required this.habit,
    this.showRightButton = true,
  });

  @override
  Widget build(BuildContext context) {
    const double cardHeight = 96;
    const double buttonRatio = 0.26;

    return SizedBox(
      height: cardHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double buttonWidth = constraints.maxWidth * buttonRatio;
          final double chipWidth = constraints.maxWidth * 0.40;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                left: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    _rivalBg,
                    fit: BoxFit.fitHeight,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              Positioned.fill(
                left: 10,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(67, 29, 18, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.only(right: 30),
                                  child: Text(
                                    '$days일 째',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: chipWidth,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '· $habit',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFD63535),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showRightButton)
                      SizedBox(
                          width: buttonWidth,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Transform.translate(
                              offset: const Offset(0, 6),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 24,
                                  bottom: 0,
                                ),
                                child: const Text(
                                  '라이벌\n보러가기',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          )
                      )
                    else
                      SizedBox(width: buttonWidth),

                  ],
                ),
              ),
              Positioned(
                left: 16,
                top: 6,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFD9D9D9),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// =======================
/// 하단 바 (해시내기 화면용)
/// =======================
class _HashBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _HashBottomBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(
          top: BorderSide(color: AppColors.caramel, width: 3),
        ),
      ),
      child: Row(
        children: List.generate(5, (i) {
          return Expanded(
            child: _BottomItem(
              index: i,
              selected: index == i,
              onTap: () => onChanged(i),
            ),
          );
        }),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;
  const _BottomItem({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['감자캐기', '해시내기', '홈화면', '알림', '마이페이지'];

    // 각 인덱스별 아이콘
    Widget icon;
    switch (index) {
      case 0: // 감자캐기
        icon = Image.asset(
          AppImages.bottomDig,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        );
        break;
      case 1: // 해시내기
        icon = Image.asset(
          AppImages.bottomHash,
          width: 35,
          height: 35,
          fit: BoxFit.contain,
        );
        break;
      case 2:
        icon = Image.asset(
          AppImages.hbLogo,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
        );
        break;
      case 3: // 알림
        icon = Image.asset(
          AppImages.alarm,
          width: 33,
          height: 33,
          fit: BoxFit.contain,
        );
        break;
      case 4: // 마이페이지
      default:
        icon = Image.asset(
          AppImages.bottomMyPage,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        );
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 46,
                  height: 38,
                  child: Center(child: icon),
                ),
                const SizedBox(height: 2),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.black87
                        : Colors.black87.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (index != 0)
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: AppColors.caramel,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

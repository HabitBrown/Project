import 'package:flutter/material.dart';
// ✅ 홈 색/이미지/홈스크린은 home_screen.dart 에서 가져오기
import 'home_screen.dart'
    show AppColors, AppImages, HomeScreen;

/// =======================
///  알림 데이터 모델
/// =======================
enum AlarmIconType { profile, megaphone }

class AlarmItem {
  final AlarmIconType type;
  final String title;      // 첫 줄
  final String? subText;   // 회색 보조 텍스트
  final String? action;    // 빨간/주황 강조 텍스트
  final String? dateText;  // 날짜

  const AlarmItem({
    required this.type,
    required this.title,
    this.subText,
    this.action,
    this.dateText,
  });
}

/// 더미 알림 데이터
const List<AlarmItem> dummyAlarms = [
  AlarmItem(
    type: AlarmIconType.profile,
    title: '이연재 농부가 도전장을 보냈습니다.',
    action: '하루에 한잔 물마시기',
  ),
  AlarmItem(
    type: AlarmIconType.megaphone,
    title: '시스템 업데이트가 되었어요.',
    dateText: '2025. 11. 19',
  ),
  AlarmItem(
    type: AlarmIconType.profile,
    title: '숨준 농부가 도전장을 수락했어요.',
    action: '하루 10000원만 쓰기',
  ),
  AlarmItem(
    type: AlarmIconType.megaphone,
    title: '내기 알림을 실패했어요.',
    action: '코딩테스트하기',
  ),
];

/// =======================
///  알림 화면
/// =======================
class AlarmScreen extends StatelessWidget {
  const AlarmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 바깥 배경도 크림색으로
      backgroundColor: AppColors.cream,

      body: SafeArea(
        bottom: false, // 아래는 하단바가 있어서 false
        child: Container(
          // 상단 상태바 아래 영역도 크림색
          color: AppColors.cream,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                children: [
                  const _AlarmHeader(),
                  // 여기서부터 아래를 전부 채우는 영역
                  Expanded(
                    child: Container(
                      color: Colors.white, // 리스트 아래 빈 공간도 흰색으로
                      child: ListView.separated(
                        itemCount: dummyAlarms.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppColors.divider,
                        ),
                        itemBuilder: (context, index) {
                          return _AlarmRow(item: dummyAlarms[index]);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // 알림 화면에도 하단바 표시
      bottomNavigationBar: _BottomBar(
        index: 3, // 알림 탭 선택 상태
        onChanged: (i) {
          if (i == 3) return; // 이미 알림 화면

          if (i == 2) {
            // 홈 화면으로 이동
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const HomeScreen(),
              ),
            );
          } else if (i == 0) {
            Navigator.pushNamed(context, '/potato');
          } else if (i == 1) {
            Navigator.pushNamed(context, '/hash');
          } else if (i == 4) {
            Navigator.pushNamed(context, '/mypage');
          }
        },
      ),
    );
  }
}

/// =======================
///  상단 "알림" 헤더
/// =======================
class _AlarmHeader extends StatelessWidget {
  const _AlarmHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: AppColors.cream,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Image.asset(
            AppImages.alarm, // lib/assets/image1/alarm.png
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          const Text(
            '알림',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  알림 한 줄
/// =======================
class _AlarmRow extends StatelessWidget {
  final AlarmItem item;
  const _AlarmRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 모든 알림에서 louder.png만 사용 (원 없음)
          SizedBox(
            width: 38,
            height: 38,
            child: Image.asset(
              'lib/assets/image1/louder.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black87,
                  ),
                ),
                if (item.subText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.subText!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ],
                if (item.action != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.action!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brick,
                    ),
                  ),
                ],
                if (item.dateText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.dateText!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.5),
                    ),
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

/// =======================
///  하단바(홈이랑 동일 모양)
/// =======================
class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomBar({required this.index, required this.onChanged});

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

    Widget icon;
    switch (index) {
      case 0:
        icon = Image.asset(
          AppImages.bottomDig,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        );
        break;
      case 1:
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
      case 3:
        icon = Image.asset(
          AppImages.alarm,
          width: 33,
          height: 33,
          fit: BoxFit.contain,
        );
        break;
      case 4:
      default:
        icon = Image.asset(
          AppImages.bottomMyPage,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        );
        break;
    }

    final bool isHome = index == 2;

    final Color labelColor =
    selected ? Colors.black87 : Colors.black87.withOpacity(0.5);

    final FontWeight labelWeight =
    isHome ? FontWeight.w500 : (selected ? FontWeight.w600 : FontWeight.w400);

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
                    fontWeight: labelWeight,
                    color: labelColor,
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
// ✅ 홈 색/이미지/홈스크린은 home_screen.dart 에서 가져오기
import 'package:pbl_front/screens/home/home_screen.dart'
    show AppColors, AppImages, HomeScreen;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/base_url.dart';
import '../../services/auth_service.dart';

/// =======================
///  알림 데이터 모델
/// =======================
enum AlarmIconType { profile, megaphone }
enum AlarmType { challenge, certification, etc } // 알람의 타입 : 도전장, 인증실패 관련, 기타 알람

class AlarmItem {
  final AlarmIconType type;
  final AlarmType alarmType; //
  final String title;      // 첫 줄
  final String? subText;   // 회색 보조 텍스트
  final String? action;    // 빨간/주황 강조 텍스트
  final String? dateText;  // 날짜

  const AlarmItem({
    required this.type,
    required this.title,
    required this.alarmType,
    this.subText,
    this.action,
    this.dateText,
  });

  /// =========================================
  ///  ✅ 백엔드 푸시(payload) → AlarmItem 변환
  /// =========================================
  ///
  /// 기대하는 payload 예시:
  /// {
  ///   "pushType": "challenge" | "certification" | "etc",
  ///   "senderName": "이연재",
  ///   "title": "하루에 한잔 물마시기", // or 기타 제목
  ///   "action": "추가로 강조하고 싶은 텍스트",
  ///   "dateText": "2025.11.19"
  /// }
  factory AlarmItem.fromPush(Map<String, dynamic> json) {
    final String pushType = (json['pushType'] as String?) ?? 'etc';
    final String? senderName = json['senderName'] as String?;
    final String? rawTitle = json['title'] as String?;
    final String? action = json['action'] as String?;
    final String? dateText = json['dateText'] as String?;

    // ============================
    // 1) 기타 알림 (etc)
    //    - 지금은 시스템 알림 용도로 사용
    //    - 서버에서 title / dateText 내려주면 우선 사용
    // ============================
    if (pushType == 'etc') {
      return AlarmItem(
        type: AlarmIconType.megaphone,
        alarmType: AlarmType.etc,
        title: rawTitle ?? '시스템 업데이트가 되었어요.',
        subText: null,
        action: action,
        dateText: dateText ?? '2025. 11. 19',
      );
    }

    // ============================
    // 2) 도전장 / 도전 관련 알림 (challenge)
    //    - senderName 이 있으면: 푸시 템플릿 문장 사용
    //    - 없으면: 서버에서 준 title 그대로 사용
    // ============================
    if (pushType == 'challenge') {
      final String displayTitle;
      if (senderName != null && senderName.isNotEmpty){
        // FCM 푸시에서 바로 들어오는 케이스 (senderName 포함)
        displayTitle = '$senderName 농부가 도전장을 보냈습니다.';
      } else {
        // /notifications 조회처럼 senderName 없는 케이스
        // → DB에 저장된 title (예: "훈이 농부가 도전장을 거절했어요.") 그대로 사용
        displayTitle = rawTitle ?? '도전장 알림이 도착했어요.';
      }
      return AlarmItem(
        alarmType: AlarmType.challenge,
        type: AlarmIconType.profile,
        title: displayTitle,
        subText: null,
        action: action ?? '',
        dateText: dateText,
      );
    }

    // ============================
    // 3) 인증 관련 알림 (certification)
    //    - 서버 title 이 있으면 그대로 사용
    //    - 없으면 기본 문장
    // ============================
    if (pushType == 'certification') {
      // certification 타입 → 인증 실패 알림
      return AlarmItem(
        alarmType: AlarmType.certification,
        type: AlarmIconType.megaphone,
        title: rawTitle ?? '인증 관련 알림이 도착했어요.',
        subText: null,
        action: action,
        dateText: dateText,
      );
    }

    // 혹시 이상한 타입 오면 안전하게 etc 처리
    return AlarmItem(
      type: AlarmIconType.megaphone,
      alarmType: AlarmType.etc,
      title: rawTitle ?? '시스템 알림이 도착했어요.',
      subText: null,
      action: action,
      dateText: dateText,
    );
  }
}









// /// 더미 알림 기본 데이터 (초기 화면용)
// const List<AlarmItem> dummyAlarms = [
//   AlarmItem(
//     type: AlarmIconType.profile,
//     alarmType: AlarmType.challenge,
//     title: '이연제 농부가 도전장을 보냈습니다.',
//     action: '하루에 한잔 물마시기',
//   ),
//   AlarmItem(
//     type: AlarmIconType.megaphone,
//     alarmType: AlarmType.etc,
//     title: '시스템 업데이트가 되었어요.',
//     dateText: '2025. 11. 19',
//   ),
//   AlarmItem(
//     type: AlarmIconType.profile,
//     alarmType: AlarmType.challenge,
//     title: '숨준 농부가 도전장을 수락했어요.',
//     action: '하루 10000원만 쓰기',
//   ),
//   AlarmItem(
//     type: AlarmIconType.megaphone,
//     alarmType: AlarmType.certification,
//     title: '내기 알림을 실패했어요.',
//     action: '코딩테스트하기',
//   ),
// ];

/// etc 타입에서 재사용할 "시스템 업데이트" 알람 템플릿
// const AlarmItem systemUpdateAlarmTemplate = AlarmItem(
//   type: AlarmIconType.megaphone,
//   alarmType: AlarmType.etc,
//   title: '시스템 업데이트가 되었어요.',
//   dateText: '2025. 11. 19',
// );

/// =======================
///  알림 화면
///  (Stateful로 변경해서 백엔드 알림 추가 가능하게 만듦)
/// =======================
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  /// 화면에 실제로 보여줄 알림 리스트
  List<AlarmItem> _alarms = [];
  bool _isLoading = false;

  void handlePushFromBackend(Map<String, dynamic> data) {
    final AlarmItem newItem = AlarmItem.fromPush(data);

    setState(() {
      // 최신 알림이 위로 오게 앞에 추가
      _alarms.insert(0, newItem);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse('$kBaseUrl/notifications');

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> items = data['items'] as List<dynamic>? ?? [];

        final alarms = items
            .map(
              (e) => AlarmItem.fromPush(e as Map<String, dynamic>),
        )
            .toList();

        setState(() {
          _alarms = alarms;
        });
      } else {
        debugPrint(
            '알림 조회 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('알림 조회 중 에러: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  /// ==========================
  ///  알림 클릭 시 동작 정의
  /// ==========================
  void _onAlarmTap(AlarmItem item) {
    switch (item.alarmType) {
      case AlarmType.challenge:
        _onChallengeAlarmTap(item);
        break;
      case AlarmType.certification:
        _onCertificationAlarmTap(item);
        break;
      case AlarmType.etc:
        _onEtcAlarmTap(item);
        break;
    }
  }

  /// 1) 도전장 알림 클릭 시 실행할 함수
  void _onChallengeAlarmTap(AlarmItem item) {
    Navigator.pushNamed(context, '/hash');
    debugPrint('챌린지 알림 클릭: ${item.title} / ${item.action}');
  }

  /// 2) 인증 실패 알림 클릭 시 실행할 함수
  void _onCertificationAlarmTap(AlarmItem item) {
    // TODO: 인증 실패 상세 화면 혹은 재도전 화면 등으로 이동
    // Navigator.pushNamed(context, '/certificationFail', arguments: item);
    debugPrint('인증 실패 알림 클릭: ${item.title} / ${item.action}');
  }

  /// 3) 기타 알림 클릭 시 실행할 함수
  void _onEtcAlarmTap(AlarmItem item) {
    // TODO: 공지사항, 시스템 업데이트 내역 화면 등으로 이동
    // Navigator.pushNamed(context, '/notice', arguments: item);
    debugPrint('기타 알림 클릭: ${item.title}');
  }

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
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _alarms.isEmpty
                            ? const Center(
                        child: Text(
                          '아직 알람이 없어요.',
                          style: TextStyle(fontSize: 14),
                          ),
                        )
                            : ListView.separated(
                              itemCount: _alarms.length,
                              separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: AppColors.divider,
                              ),
                              itemBuilder: (context, index) {
                                final item = _alarms[index];
                                return _AlarmRow(
                                  item: item,
                                  onTap: () => _onAlarmTap(item),
                                );
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
/// =======================
///  알림 한 줄
/// =======================
class _AlarmRow extends StatelessWidget {
  final AlarmItem item;
  final VoidCallback? onTap;

  const _AlarmRow({
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 알림 타입에 따라 아이콘 다르게 표시
    Widget leadingIcon;
    switch (item.type) {
      case AlarmIconType.profile:
        leadingIcon = SizedBox(
          width: 38,
          height: 38,
          child: Image.asset(
            AppImages.bottomMyPage,  // 프로필 느낌 아이콘
            fit: BoxFit.contain,
          ),
        );
        break;

      case AlarmIconType.megaphone:
      default:
        leadingIcon = SizedBox(
          width: 38,
          height: 38,
          child: Image.asset(
            'lib/assets/image2/loud.png',  // 기존 메가폰 이미지
            fit: BoxFit.contain,
          ),
        );
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leadingIcon,
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

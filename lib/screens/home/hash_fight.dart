import 'package:flutter/material.dart';

/// -----------------------------
/// 색상 모음 (이 화면 전용)
/// -----------------------------
class HashFightColors {
  static const brown = Color(0xFFBF8D6A); // 상단바, 포인트
  static const cream = Color(0xFFFFF8E1); // 전체 배경
  static const dark = Color(0xFF535353); // 기본 텍스트
  static const brick = Color(0xFFC32B2B); // 진한 빨간 텍스트
  static const danger = Color(0xFFE25B5B); // 느낌표 배경
  static const bubble = Color(0xFFF6F1DC); // 일반 말풍선
  static const failBubble = Color(0xFFF3D49B); // 실패 말풍선
  static const divider = Color(0xFFD8CBB6); // 테두리
  static const green = Color(0xFFAFDBAE); // 버튼
  static const avatarGrey = Color(0xFFE0E0E0); // 프로필 원
  static const talkColor = Color(0xFFF3C75A);
}

/// -----------------------------
/// DTO / 구조체 정의
/// -----------------------------
/// ===== 백엔드 Certification DTO =====

enum CertMethod { photo, text }
enum CertStatus { success, fail }

class Certification {
  final int id;
  final int userId;
  final int? userHabitId;
  final int? duelId;
  final DateTime tsUtc;
  final CertMethod method;
  final CertStatus status;
  final String? textContent;
  final int? photoAssetId;
  final String? failReason;

  Certification({
    required this.id,
    required this.userId,
    required this.userHabitId,
    required this.duelId,
    required this.tsUtc,
    required this.method,
    required this.status,
    this.textContent,
    this.photoAssetId,
    this.failReason,
  });

  /// 백엔드 JSON → Certification
  factory Certification.fromJson(Map<String, dynamic> json) {
    return Certification(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      userHabitId: json['user_habit_id'] as int?,
      duelId: json['duel_id'] as int?,
      tsUtc: DateTime.parse(json['ts_utc'] as String),
      method: (json['method'] == 'photo')
          ? CertMethod.photo
          : CertMethod.text,
      status: (json['status'] == 'success')
          ? CertStatus.success
          : CertStatus.fail,
      textContent: json['text_content'] as String?,
      photoAssetId: json['photo_asset_id'] as int?,
      failReason: json['fail_reason'] as String?,
    );
  }
}


//매핑 함수
/// Certification → HashFightMessage 변환
HashFightMessage certificationToHashFightMessage({
  required Certification cert,
  required int myUserId,        // 내가 누구인지
  required String habitTitle,   // 습관 이름 (필요하면 서버에서 같이 내려줌)
  String? photoUrl,             // photo_asset_id → storage_url 로 변환한 값
}) {
  // 1) 누가 보낸 건지 (나 vs 상대)
  final sender = (cert.userId == myUserId)
      ? HashFightSender.me
      : HashFightSender.partner;

  // 2) 메시지 타입 매핑
  late HashFightMessageType type;

  if (cert.status == CertStatus.success) {
    // 성공인 경우 → method가 photo인지 text인지에 따라
    if (cert.method == CertMethod.photo) {
      type = HashFightMessageType.photo;
    } else {
      type = HashFightMessageType.text;
    }
  } else {
    // 실패인 경우 → failReason에 따라 구분하고 싶으면 여기서 분기
    if (cert.failReason == 'TIME_OVER') {
      type = HashFightMessageType.failTime;
    } else {
      // 예: NO_PHOTO, NO_TEXT 등
      type = HashFightMessageType.wrongCert;
    }
  }

  return HashFightMessage(
    id: cert.id.toString(),
    createdAt: cert.tsUtc.toLocal(),  // UTC → 로컬 시간
    habitTitle: habitTitle,
    sender: sender,
    type: type,
    imageUrl: (cert.method == CertMethod.photo) ? photoUrl : null,
    text: (cert.method == CertMethod.text)
        ? cert.textContent
        : cert.failReason,   // 실패 말풍선에 보여줄 문구로 사용
  );
}









/// 누가 보낸 메시지인가
enum HashFightSender { me, partner }

/// 메시지 타입
enum HashFightMessageType {
  photo, // 인증 사진
  text, // 인증 글(텍스트)
  failTime, // 시간 초과 실패
  wrongCert, // 이의제기 실패
}

/// 채팅 메시지 하나
class HashFightMessage {
  final String id; // 백엔드에서 전달되는 고유 id 가정
  final DateTime createdAt; // 인증/실패 시간
  final String habitTitle; // 습관 제목 (예: "코딩테스트 하기")
  final HashFightSender sender; // me / partner
  final HashFightMessageType type;
  final String? imageUrl; // 사진 인증일 경우
  final String? text; // 텍스트 인증 or 실패 안내 문구

  HashFightMessage({
    required this.id,
    required this.createdAt,
    required this.habitTitle,
    required this.sender,
    required this.type,
    this.imageUrl,
    this.text,
  });
}

/// 한 상대와의 내기 대화(방) 정보
class HashFightConversation {
  final String id; // 방 id
  final String partnerName; // 상대 이름
  final int remainFailCount; // 남은 인증 실패 가능 횟수
  final List<HashFightMessage> messages;

  HashFightConversation({
    required this.id,
    required this.partnerName,
    required this.remainFailCount,
    required this.messages,
  });
}

/// 이의제기 payload (나중에 백엔드에 보낼 구조)
class HashObjectionPayload {
  final String messageId;
  final bool reasonPhotoWrong; // 인증 사진/글이 잘못됨
  final bool reasonEtc; // 기타 체크 여부
  final String etcContent; // 기타 내용

  HashObjectionPayload({
    required this.messageId,
    required this.reasonPhotoWrong,
    required this.reasonEtc,
    required this.etcContent,
  });
}

/// -----------------------------
/// 메인 화면 위젯
/// -----------------------------
/// 지금은 더미 데이터로만 화면을 그리고,
/// 나중에 백엔드 붙일 때 이 페이지 안에서 API 호출 + DTO 매핑만 바꿔주면 됨.
class HashFightPage extends StatefulWidget {
  const HashFightPage({Key? key}) : super(key: key);

  @override
  State<HashFightPage> createState() => _HashFightPageState();
}

class _HashFightPageState extends State<HashFightPage> {
  late final HashFightConversation _conversation;

  bool _showObjection = false;
  String? _targetMessageId;

  bool _reasonPhotoWrong = false;

  bool _reasonEtc = false;
  final TextEditingController _etcController = TextEditingController();
  bool _showGiveUpDialog = false;

  @override
  void initState() {
    super.initState();
    _conversation = _buildDummyConversation(); // 일단 더미 데이터로 화면 테스트
  }

  @override
  void dispose() {
    _etcController.dispose();
    super.dispose();
  }

  /// 더미 데이터 (백엔드 붙기 전까지 화면용)
  HashFightConversation _buildDummyConversation() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1)); // 👈 어제 날짜

    return HashFightConversation(
      id: 'conv-1',
      partnerName: '송강호',
      remainFailCount: 1,
      messages: [
        // 1) 상대방이 사진으로 인증 (어제)
        HashFightMessage(
          id: 'm1',
          createdAt: yesterday,
          habitTitle: '영양제 챙겨먹기',
          sender: HashFightSender.partner,
          type: HashFightMessageType.photo,
          imageUrl: 'lib/assets/image2/pill.jpg',
        ),
        // 2) 내가 오늘 사진으로 인증
        HashFightMessage(
          id: 'm2',
          createdAt: now,
          habitTitle: '코딩테스트 하기',
          sender: HashFightSender.me,
          type: HashFightMessageType.photo,
          imageUrl: 'lib/assets/image2/coding.png',
        ),
        // 3) 상대가 시간초과로 인증 실패 (왼쪽 노란 말풍선)
        HashFightMessage(
          id: 'm3',
          createdAt: now,
          habitTitle: '코딩테스트 하기',
          sender: HashFightSender.partner,
          type: HashFightMessageType.failTime,
          text: '정해진 인증 시간이 지나서\n인증 실패 하였습니다.',
        ),
        // 4) 내가 사진을 안 올려서 실패 (오른쪽 노란 말풍선)
        HashFightMessage(
          id: 'm4',
          createdAt: now,
          habitTitle: '코딩테스트 하기',
          sender: HashFightSender.me,
          type: HashFightMessageType.wrongCert,
          text: '사진을 등록하지 않아\n인증 실패 하였습니다.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HashFightColors.cream,
      appBar: AppBar(
        backgroundColor: HashFightColors.brown,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _conversation.partnerName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 4,
                ),
                backgroundColor: HashFightColors.cream,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                setState(() {
                  _showGiveUpDialog = true;  // 내기 포기 팝업 ON
                  _showObjection = false;    // 이의제기 팝업 OFF
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔥 이미지 넣는 자리 (경로 수정!)
                  Image.asset(
                    'lib/assets/image2/sad_potato.png',
                    width: 20,
                    height: 20,
                  ),

                  const SizedBox(width: 7),

                  const Text(
                    '포기\n하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: HashFightColors.brown,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 24),
              Text(
                '남은 인증 실패 가능 횟수: ${_conversation.remainFailCount}회',
                style: const TextStyle(
                  color: HashFightColors.brick,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: _conversation.messages.length,
                  itemBuilder: (context, index) {
                    final msg = _conversation.messages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildMessage(msg),
                    );
                  },
                ),
              ),
            ],
          ),

          if (_showObjection) _buildObjectionDialog(context),
          if (_showGiveUpDialog) _buildGiveUpDialog(),
        ],
      ),
    );
  }

  /// 메시지 타입/보낸 사람에 따라 말풍선 모양을 다르게 그림
  Widget _buildMessage(HashFightMessage msg) {
    final dateStr =
        '${msg.createdAt.year}.${msg.createdAt.month}.${msg.createdAt.day}';

    if (msg.type == HashFightMessageType.photo ||
        msg.type == HashFightMessageType.text) {
      // 인증(성공) 메시지: 사진 또는 글
      if (msg.sender == HashFightSender.partner) {
        return _buildLeftVerifyBubble(msg, dateStr);
      } else {
        return _buildRightVerifyBubble(msg, dateStr);
      }
    } else {
      // 실패 메시지
      if (msg.sender == HashFightSender.partner) {
        return _buildLeftFailBubble(msg, dateStr);
      } else {
        return _buildRightFailBubble(msg, dateStr);
      }
    }
  }

  // -------------------------------
  //   왼쪽 인증 말풍선 (상대방)
  // -------------------------------
  Widget _buildLeftVerifyBubble(HashFightMessage msg, String date) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatarWithName(_conversation.partnerName),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateAndTitle(date, msg.habitTitle),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 말풍선 (사진/텍스트)
                  Flexible(child: _buildVerifyContent(msg)),
                  const SizedBox(width: 6),
                  // 이의제기 버튼 (말풍선 오른쪽 옆)
                  _exclamationButton(() => _openObjection(msg.id)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------
  //   오른쪽 인증 말풍선 (나)
  // -------------------------------
  Widget _buildRightVerifyBubble(HashFightMessage msg, String date) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildDateAndTitle(date, msg.habitTitle, alignEnd: true),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 6),
                  // 이의제기 버튼 (말풍선 오른쪽 옆)
                  _exclamationButton(() => _openObjection(msg.id)),
                  // 말풍선 (사진/텍스트)
                  Flexible(child: _buildVerifyContent(msg)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildAvatarWithName('나'),
      ],
    );
  }

  /// 인증 말풍선 안쪽 내용 (사진 or 텍스트)
  Widget _buildVerifyContent(HashFightMessage msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HashFightColors.bubble,
        borderRadius: BorderRadius.circular(16),
      ),
      child: msg.type == HashFightMessageType.photo
          ? AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: msg.imageUrl != null
              ? Image.asset(
            msg.imageUrl!,
            fit: BoxFit.cover,
          )
              : Container(color: Colors.black),
        ),
      )
          : Text(
        msg.text ?? '',
        style: const TextStyle(
          fontSize: 14,
          color: HashFightColors.dark,
        ),
      ),
    );
  }

  // -------------------------------
  //   왼쪽 실패 말풍선 (상대방)
  // -------------------------------
  Widget _buildLeftFailBubble(HashFightMessage msg, String date) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatarWithName(_conversation.partnerName),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 13,
                  color: HashFightColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(child: _buildFailContent(msg)),
                  const SizedBox(width: 6),
                  _exclamationButton(() => _openObjection(msg.id)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------
  //   오른쪽 실패 말풍선 (나)
  // -------------------------------
  Widget _buildRightFailBubble(HashFightMessage msg, String date) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 13,
                  color: HashFightColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _exclamationButton(() => _openObjection(msg.id)),
                  const SizedBox(width: 6),
                  Flexible(child: _buildFailContent(msg)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildAvatarWithName('나'),
      ],
    );
  }

  /// 실패 말풍선 안쪽 노란 박스
  Widget _buildFailContent(HashFightMessage msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: HashFightColors.failBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        msg.text ?? '인증 실패 하였습니다.',
        style: const TextStyle(fontSize: 14, color: HashFightColors.dark),
      ),
    );
  }

  // 날짜 + 습관 제목
  Widget _buildDateAndTitle(String date, String title,
      {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment:
      alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: HashFightColors.talkColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: HashFightColors.dark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(width: 5),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 5),
            Text(
              date,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: HashFightColors.dark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 아바타 + 이름
  Widget _buildAvatarWithName(String name) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: HashFightColors.avatarGrey,
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 12, color: HashFightColors.dark),
        ),
      ],
    );
  }

  // 빨간 느낌표 버튼
  Widget _exclamationButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: HashFightColors.danger,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text(
          '!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            height: 1,
          ),
        ),
      ),
    );
  }

  void _openObjection(String messageId) {
    setState(() {
      _targetMessageId = messageId;
      _showObjection = true;
      _showGiveUpDialog = false;
      _reasonPhotoWrong = false;
      _reasonEtc = false;
      _etcController.clear();
    });
  }

  // =======================
  //   내기 포기 팝업
  // =======================
  Widget _buildGiveUpDialog() {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: HashFightColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            const Text(
              '내기를 정말 포기 하실건가요?',
              style: TextStyle(
                fontSize: 15,
                color: HashFightColors.dark,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              '내기에 건 해시 브라운을 잃게 됩니다.',
              style: TextStyle(fontSize: 13, color: HashFightColors.dark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // 버튼 + 감자 이미지 줄
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 예 버튼
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HashFightColors.brick,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // TODO: 여기서 백엔드에 "포기하기" API 호출
                        // 예시로는 그냥 화면 나가기:
                        Navigator.of(context).pop(); // 내기 화면 종료
                      },
                      child: const Text(
                        '예',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 아니요 버튼
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HashFightColors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // 팝업만 닫기
                        setState(() {
                          _showGiveUpDialog = false;
                        });
                      },
                      child: const Text(
                        '아니요',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 우는 감자 아이콘 자리
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: HashFightColors.cream,
                    ),
                    child:
                    Image.asset('lib/assets/image2/sad_potato.png'),

                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------
  //   이의제기 팝업
  // -------------------------------
  Widget _buildObjectionDialog(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        setState(() {
          _showObjection = false;
        });
      },
      child: Center(
        child: GestureDetector(
          onTap: () {},  // 팝업 내부는 닫히지 않게
          child: Container(
            width: 260,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HashFightColors.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '이의 제기 하기!',
                    style: TextStyle(
                      color: HashFightColors.brick,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildCheckRow(
                  value: _reasonPhotoWrong,
                  label: '인증 사진/글이 잘못됐어요',
                  onChanged: (v) => setState(() => _reasonPhotoWrong = v ?? false),
                ),
                const SizedBox(height: 6),
                _buildCheckRow(
                  value: _reasonEtc,
                  label: '기타',
                  onChanged: (v) => setState(() => _reasonEtc = v ?? false),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _etcController,
                  maxLines: 1,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: HashFightColors.divider),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HashFightColors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (_targetMessageId == null) {
                        setState(() => _showObjection = false);
                        return;
                      }

                      final payload = HashObjectionPayload(
                        messageId: _targetMessageId!,
                        reasonPhotoWrong: _reasonPhotoWrong,
                        reasonEtc: _reasonEtc,
                        etcContent: _etcController.text.trim(),
                      );

                      setState(() {
                        _showObjection = false;
                      });
                    },
                    child: const Text(
                      '제출',
                      style: TextStyle(
                        color: HashFightColors.dark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildCheckRow({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: HashFightColors.green,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: HashFightColors.dark),
          ),
        ),
      ],
    );
  }
}
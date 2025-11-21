// 인증하기 창
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/farmer.dart';
import 'habit_setting.dart';
import 'package:image_picker/image_picker.dart';

class CertPage extends StatefulWidget {
  const CertPage({
    super.key,
    required this.habitTitle,
    required this.nickname,
    required this.method,
    this.deadline,
    this.setup,
  });

  final String habitTitle;
  final String method;
  final String nickname;
  final String? deadline;
  final HabitSetupData? setup;

  @override
  State<CertPage> createState() => _CertPageState();
}

class _CertPageState extends State<CertPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isTextFilled = false;

  // ✅ 사진 인증용 상태
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isTextFilled = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final method = widget.method;
    final setup = widget.setup;
    final habitTitle = widget.habitTitle;
    final deadline = widget.deadline;
    final nickname = widget.nickname;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Column(
          children: [
            _backOnlyTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 2),
                    _thinkingBubble(habitTitle),
                    const SizedBox(height: 26),

                    // 닉네임 줄
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '· $nickname 님은',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF535353),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 갈색 정보 박스
                    Center(
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA9783F),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _buildInfoBox(setup, method, deadline),
                      ),
                    ),

                    const SizedBox(height: 26),
                    const Text(
                      '인증하기로 했어요!',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF535353),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ✅ 여기서 방식에 따라 분기
                    if (method == '사진')
                      _photoCertSection(context)   // ← 새로 만든 위젯
                    else
                      _textForm(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔙 상단 뒤로가기
  Widget _backOnlyTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 22,
              color: Color(0xFF6D4A2C),
            ),
          ),
        ],
      ),
    );
  }

  // 💭 감자가 생각하는 말풍선
  Widget _thinkingBubble(String habitTitle) {
    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 20,
            top: 28,
            child: Image.asset(
              'lib/assets/image1/gamja1.png',
              width: 68,
            ),
          ),
          Positioned(
            left: 62,
            top: 58,
            child: Image.asset(
              'lib/assets/image1/thinking bubble.png',
              width: 310,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 120,
            top: 135,
            right: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '· $habitTitle',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E3E3E),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 110),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '습관을 인증할까요?',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF535353),
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🟤 갈색 정보 박스 내부 텍스트
  Widget _buildInfoBox(HabitSetupData? setup, String method, String? deadline) {
    if (setup != null) {
      final s = setup;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('· 매주 ${_weekdayLabel(s.weekdays)}',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 4),
          Text('· ${_fmtDate(s.startDate)} 부터 ${_fmtDate(s.endDate)}까지',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 4),
          Text('· ${_toKoreanTime(s.deadline)} 까지',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 4),
          Text(s.certType == CertType.photo ? '· 사진으로' : '· 글로',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('· 매일', style: TextStyle(color: Colors.white, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('· 오늘부터 계속',
            style: TextStyle(color: Colors.white, fontSize: 13)),
        const SizedBox(height: 4),
        Text('· ${_toKoreanTime(deadline ?? "23:59")} 까지',
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        const SizedBox(height: 4),
        Text(method == '글' ? '· 글로' : '· 사진으로',
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  // ✅ 사진 인증 섹션 (버튼 + 미리보기 + 업로드)
  // ✅ 사진 인증 섹션 (수정 버전)
  Widget _photoCertSection(BuildContext context) {
    final hasImage = _pickedImage != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) 사진 없을 때: 가운데 큰 첨부 버튼
          if (!hasImage)
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Image.asset(
                  'lib/assets/image1/camera_upload.png',
                  width: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          if (hasImage) ...[
            // 2) 사진 미리보기
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Image.file(
                File(_pickedImage!.path),
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 18),

            // 3) 업로드하기 + 사진 교체하기
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _pickImage,
                  style: TextButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFF535353),
                  ),
                  child: const Text(
                    '사진 교체하기',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3C34E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    child: Text(
                      '업로드 하기',
                      style: TextStyle(
                        color: Color(0xFF535353),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }



  // ✅ 실제로 사진 고르는 메서드 (bottom sheet 그대로 살림)
  Future<void> _pickImage() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.brown),
                title: const Text('사진 촬영하기'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading:
                const Icon(Icons.photo_library, color: Colors.brown),
                title: const Text('갤러리에서 선택하기'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null) return;

    XFile? picked;
    if (choice == 'camera') {
      picked = await _picker.pickImage(source: ImageSource.camera);
    } else {
      picked = await _picker.pickImage(source: ImageSource.gallery);
    }

    if (picked != null) {
      setState(() {
        _pickedImage = picked;    // ← 화면에 보여주기만 하고 닫지 않음
      });
    }
  }

  // ✍️ 글 인증 (기존 그대로)
  Widget _textForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        children: [
          Container(
            height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEAD1A1)),
            ),
            child: TextField(
              controller: _controller,
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTextFilled
                    ? const Color(0xFFF3C34E)
                    : Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed:
              _isTextFilled ? () => Navigator.pop(context, true) : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Text(
                  '업로드 하기',
                  style: TextStyle(
                    color: Color(0xFF535353),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🕒 유틸 함수들
  String _toKoreanTime(String hm) {
    final parts = hm.split(':');
    if (parts.length != 2) return hm;
    var h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final isPm = h >= 12;
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    final ampm = isPm ? '오후' : '오전';
    return '$ampm $h시 ${m.toString().padLeft(2, '0')}분';
  }

  String _fmtDate(DateTime d) => '${d.year}.${d.month}.${d.day}';

  String _weekdayLabel(List<int> days) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return days
        .where((d) => d >= 1 && d <= 7)
        .map((d) => labels[d - 1])
        .join(', ');
  }
}

// 인증하기 창
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/farmer.dart';
import 'habit_setting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../../services/certification_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CertPage extends StatefulWidget {
  const CertPage({
    super.key,
    required this.userHabitId,
    required this.habitTitle,
    required this.nickname,
    required this.method,
    this.deadline,
    this.setup,
  });

  final int userHabitId;
  final String habitTitle;
  final String method;
  final String nickname;
  final String? deadline;
  final HabitSetupData? setup;

  @override
  State<CertPage> createState() => _CertPageState();
}

class _CertPageState extends State<CertPage> {
  final CertificationService _certService = CertificationService();

  final TextEditingController _controller = TextEditingController();
  bool _isTextFilled = false;

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

  // ✅ 추가된 압축 함수
  Future<File> _compressImage(XFile xfile) async {
    final String targetPath = '${xfile.path}_compressed.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      xfile.path,
      targetPath,
      quality: 50,
      minWidth: 900,
      minHeight: 900,
    );

    return File(compressed?.path ?? xfile.path);
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

                    if (method == 'photo')
                      _photoCertSection(context)
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
          Text(
              s.certType == CertType.photo ? '· 사진으로' : '· 글로',
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
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        const SizedBox(height: 4),
        Text('· ${_toKoreanTime(deadline ?? "23:59")} 까지',
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        const SizedBox(height: 4),
        Text(method == '글' ? '· 글로' : '· 사진으로',
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  // =============================
  // 📸 사진 인증 UI
  // =============================
  Widget _photoCertSection(BuildContext context) {
    final hasImage = _pickedImage != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              child: kIsWeb
                  ? Image.network(_pickedImage!.path, fit: BoxFit.cover)
                  : Image.file(File(_pickedImage!.path), fit: BoxFit.cover),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _pickImage,
                  child: const Text('사진 교체하기',
                      style: TextStyle(fontSize: 12, color: Color(0xFF535353))),
                ),
                const SizedBox(width: 8),

                // =============================
                // 💛 업로드 버튼 (압축 적용)
                // =============================
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3C34E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (_pickedImage == null) return;

                    try {
                      // 1) 압축 적용
                      final File compressedFile =
                      await _compressImage(_pickedImage!);

                      // 2) 서버에 업로드
                      final photoId =
                      await _certService.uploadPhoto(compressedFile);

                      // 3) 인증 요청
                      await _certService.createPhotoCertification(
                        userHabitId: widget.userHabitId,
                        photoAssetId: photoId,
                      );

                      Navigator.pop(context, true);
                    } catch (e) {
                      print('사진 인증 실패: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                          Text('사진 인증에 실패했어요. 다시 시도해주세요.'),
                        ),
                      );
                    }
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

  // =============================
  // 사진 고르기
  // =============================
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
                leading: const Icon(Icons.photo_library, color: Colors.brown),
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
        _pickedImage = picked;
      });
    }
  }

  // =============================
  // 글 인증
  // =============================
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
              onPressed: _isTextFilled
                  ? () async {
                try {
                  await _certService.createTextCertification(
                    userHabitId: widget.userHabitId,
                    textContent: _controller.text.trim(),
                  );
                  Navigator.pop(context, true);
                } catch (e) {
                  print('인증 실패: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                      Text('인증에 실패했어요. 다시 시도해주세요.'),
                    ),
                  );
                }
              }
                  : null,
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

  // =============================
  // 기타 유틸 함수들
  // =============================
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

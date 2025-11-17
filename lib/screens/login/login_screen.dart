import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

/// =======================
/// Config: 색/치수/에셋 경로
/// =======================
class AppColors {
  static const cream = Color(0xFFFFF8E1);  // 배경
  static const green = Color(0xFFAFDBAE);  // 버튼
  static const brown = Color(0xFFBF8D6A);  // 테두리
  static const dark  = Color(0xFF535353);  // 텍스트
  static const white = Color(0xFFFFFFFF);  // 흰색
  static const error = Colors.red;
}

class Dimens {
  static const fieldHeight = 48.0;
  static const fieldRadius = 20.0;
  static const loginBtnW = 71.0;
  static const loginBtnH = 114.0;
  static const loginBtnRadius = 15.0;
  static const pageHPad = 24.0;
}

/// 에셋 경로 (네가 lib/assets 에 둘 땐 아래처럼)
/// pubspec.yaml 에도 같은 경로가 등록되어야 함!
///   assets:
///     - lib/assets/
/// 루트 assets/ 를 쓰면 'assets/habit_logo.png' 로 바꿔줘.
const kLogoPath = 'lib/assets/image1/habit_logo.png';

/// =======================
/// Login Screen
/// =======================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phoneC = TextEditingController();
  final _pwC    = TextEditingController();

  // 각 필드만 에러 해제하기 위한 키
  final _phoneFieldKey = GlobalKey<FormFieldState<String>>();
  final _pwFieldKey    = GlobalKey<FormFieldState<String>>();

  bool _obscure = true;
  bool _autoValidate = false; // 로그인 시도 후 자동 검증 켜기

  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _phoneC.dispose();
    _pwC.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '전화번호를 입력하세요';
    if (s.length < 9) return '전화번호가 너무 짧습니다';
    // 필요하면 정규식으로 more strict
    return null;
  }

  String? _validatePassword(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return '비밀번호를 입력하세요';
    if (s.length < 8) return '비밀번호는 8자리 이상';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _autoValidate = true);
    final ok = _formKey.currentState!.validate();
    if (!ok || _loading) return;

    setState(() => _loading = true);
    try {
      // 백엔드 로그인 호출
      await _auth.login(
        phone: _phoneC.text.trim(),
        password: _pwC.text,
      );

      if (!mounted) return;
      // 홈 화면으로 이동
      Navigator.pushReplacementNamed(context, '/home', arguments: {
        // 필요하면 로그인 응답의 user 정보로 채우기
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Dimens.pageHPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 로고
                Image.asset(
                  kLogoPath,
                  width: 281,
                  height: 296,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 50),

                // 폼
                Form(
                  key: _formKey,
                  autovalidateMode:
                  _autoValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
                  child: Stack(
                    children: [
                      // 입력칸들: 버튼 폭만큼 오른쪽 여백
                      Padding(
                        padding: const EdgeInsets.only(right: 90),
                        child: Column(
                          children: [
                            _RoundedField(
                              key: _phoneFieldKey,
                              controller: _phoneC,
                              hint: '전화번호',
                              obscure: false,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: _validatePhone,
                              onTap: () => _phoneFieldKey.currentState?.reset(), // 탭 시 에러 해제
                            ),
                            const SizedBox(height: 8),
                            _RoundedField(
                              key: _pwFieldKey,
                              controller: _pwC,
                              hint: '비밀번호',
                              obscure: _obscure,
                              validator: _validatePassword,
                              onTap: () => _pwFieldKey.currentState?.reset(), // 탭 시 에러 해제
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.dark,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 로그인 버튼 (세로 pill)
                      Align(
                        alignment: Alignment.centerRight,
                        child: _LoginPillButton(
                          label: 'login',
                          background: AppColors.green,
                          foreground: AppColors.white,
                          onTap: _submit,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: const Text(
                    '회원가입하기',
                    style: TextStyle(
                      color: AppColors.dark,
                      decoration: TextDecoration.underline,
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
}

/// 공통 둥근 입력 필드
class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback? onTap;
  final Widget? suffix;


  const _RoundedField({
    super.key,
    required this.controller,
    required this.hint,
    required this.obscure,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.onTap,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Dimens.fieldHeight + 12, // 에러 줄 공간 포함 살짝 여유
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        onTap: onTap, // 탭하면 해당 필드 에러만 리셋
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: AppColors.dark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.dark),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

          // 에러 문구 보이면서도 높이 점프 방지 (항상 한 줄 예약)
          helperText: '',
          errorStyle: const TextStyle(color: AppColors.error, fontSize: 12, height: 1.1),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimens.fieldRadius),
            borderSide: const BorderSide(color: AppColors.brown, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimens.fieldRadius),
            borderSide: const BorderSide(color: AppColors.brown, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimens.fieldRadius),
            borderSide: const BorderSide(color: AppColors.brown, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimens.fieldRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimens.fieldRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 1.6),
          ),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

/// 세로로 긴 pill 버튼 (W=71, H=114, r=15)
class _LoginPillButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _LoginPillButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(Dimens.loginBtnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimens.loginBtnRadius),
        onTap: onTap,
        child: SizedBox(
          width: Dimens.loginBtnW,
          height: Dimens.loginBtnH,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

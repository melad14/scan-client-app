import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:dr_ray/core/utils/constants.dart';
import 'package:dr_ray/core/utils/validators.dart';
import 'package:dr_ray/features/auth/auth_glass_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final TextEditingController _usernameController        = TextEditingController();
  final TextEditingController _nameController            = TextEditingController();
  final TextEditingController _emailController           = TextEditingController();
  final TextEditingController _phoneController           = TextEditingController();
  final TextEditingController _ageController             = TextEditingController();
  final TextEditingController _passwordController        = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _nameFocus     = FocusNode();
  final FocusNode _emailFocus    = FocusNode();
  final FocusNode _phoneFocus    = FocusNode();
  final FocusNode _ageFocus      = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus  = FocusNode();

  String _selectedGender = 'male';
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late AnimationController _bgController;
  late Animation<double> _bgAnim;
  late AnimationController _pulseController;

  final _dio = Dio(BaseOptions(
    baseUrl: Constants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.linear);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);

    // Repaint so the focus ring follows the caret.
    for (final f in [
      _usernameFocus, _nameFocus, _emailFocus,
      _phoneFocus, _ageFocus, _passwordFocus, _confirmFocus,
    ]) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocus.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _ageFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// Per-field errors, shown under the field they belong to.
  final Map<String, String?> _fieldErrors = {};

  void _clearFieldError(String key) {
    if (_fieldErrors[key] != null) setState(() => _fieldErrors[key] = null);
  }

  /// Fills [_fieldErrors] and returns true when every field is valid.
  /// All fields are checked at once so the user sees everything that is wrong.
  bool _validateAll() {
    final password = _passwordController.text;
    final errors = <String, String?>{
      'username': validateUsername(_usernameController.text),
      'name': validateFullName(_nameController.text),
      'email': validateEmail(_emailController.text),
      'phone': validateEgyptPhone(_phoneController.text),
      'age': validateAge(_ageController.text),
      'password': validatePassword(password),
      'confirm': password != _confirmPasswordController.text
          ? 'كلمتا المرور غير متطابقتين'
          : null,
    };
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
      _errorMessage = null;
    });
    return errors.values.every((e) => e == null);
  }

  Future<void> _handleRegister() async {
    if (!_validateAll()) return;

    final username = _usernameController.text.trim();
    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim();
    final phone    = normaliseEgyptPhone(_phoneController.text);
    final age      = _ageController.text.trim();
    final password = _passwordController.text.trim();

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final res = await _dio.post(Constants.patientRegister, data: {
        'username': username,
        'name':     name,
        'email':    email,
        'phone':    phone,
        'age':      int.parse(age),
        'gender':   _selectedGender,
        'password': password,
      });

      if (res.statusCode == 201 && res.data['success'] == true) {
        final userId = res.data['data']['userId']?.toString() ?? '';
        final userEmail = res.data['data']['email']?.toString() ?? email;

        if (mounted) {
          context.go('/verify-email', extra: {'userId': userId, 'email': userEmail});
        }
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      String? serverMsg;
      if (e.response?.data is Map) {
        serverMsg = e.response?.data['message']?.toString();
      } else if (e.response?.data is String) {
        serverMsg = e.response?.data as String;
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        setState(() => _errorMessage = 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.');
      } else if (statusCode == 400 && serverMsg != null) {
        // Put "already registered" errors under the field they belong to
        // instead of a generic banner the user has to map themselves.
        final key = serverMsg.contains('اسم المستخدم')
            ? 'username'
            : serverMsg.contains('البريد')
                ? 'email'
                : serverMsg.contains('هاتف')
                    ? 'phone'
                    : null;
        setState(() {
          if (key != null) {
            _fieldErrors[key] = serverMsg;
          } else {
            _errorMessage = serverMsg;
          }
        });
      } else if (statusCode == 429) {
        setState(() => _errorMessage = 'محاولات كثيرة. انتظر قليلاً وحاول مرة أخرى.');
      } else {
        setState(() => _errorMessage = serverMsg ?? 'فشل إنشاء الحساب. حاول مرة أخرى.');
      }
    } catch (_) {
      setState(() => _errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            AuthAnimatedBackground(
              controller: _bgAnim,
              pulseController: _pulseController,
              size: size,
            ),

            // Back to login
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: size.height * 0.05),

                        const AuthBrandHeader(
                          tagline: 'أنشئ حسابك وابدأ أول حجز',
                          logoSize: 72,
                        ),

                        SizedBox(height: size.height * 0.035),

                        AuthGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'حساب جديد',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'خطوة واحدة وتقدر تحجز ✨',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.5),
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 24),

                              if (_errorMessage != null) ...[
                                AuthGlassErrorBanner(
                                  message: _errorMessage!,
                                  onClose: () => setState(() => _errorMessage = null),
                                ),
                                const SizedBox(height: 20),
                              ],

                              AuthGlassInputField(
                                controller: _usernameController,
                                focusNode: _usernameFocus,
                                isFocused: _usernameFocus.hasFocus,
                                label: 'اسم المستخدم',
                                hint: 'ahmed_123',
                                icon: Icons.alternate_email_rounded,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                errorText: _fieldErrors['username'],
                                onChanged: (_) => _clearFieldError('username'),
                                onSubmitted: (_) => _nameFocus.requestFocus(),
                              ),
                              const SizedBox(height: 16),

                              AuthGlassInputField(
                                controller: _nameController,
                                focusNode: _nameFocus,
                                isFocused: _nameFocus.hasFocus,
                                label: 'الاسم بالكامل',
                                hint: 'محمد أحمد',
                                icon: Icons.person_outline_rounded,
                                textAlign: TextAlign.right,
                                errorText: _fieldErrors['name'],
                                onChanged: (_) => _clearFieldError('name'),
                                onSubmitted: (_) => _emailFocus.requestFocus(),
                              ),
                              const SizedBox(height: 16),

                              AuthGlassInputField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                isFocused: _emailFocus.hasFocus,
                                label: 'البريد الإلكتروني',
                                hint: 'example@email.com',
                                icon: Icons.email_outlined,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                keyboardType: TextInputType.emailAddress,
                                errorText: _fieldErrors['email'],
                                onChanged: (_) => _clearFieldError('email'),
                                onSubmitted: (_) => _phoneFocus.requestFocus(),
                              ),
                              const SizedBox(height: 16),

                              AuthGlassInputField(
                                controller: _phoneController,
                                focusNode: _phoneFocus,
                                isFocused: _phoneFocus.hasFocus,
                                label: 'رقم الهاتف',
                                hint: '01012345678',
                                icon: Icons.phone_outlined,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                keyboardType: TextInputType.phone,
                                errorText: _fieldErrors['phone'],
                                onChanged: (_) => _clearFieldError('phone'),
                                onSubmitted: (_) => _ageFocus.requestFocus(),
                              ),
                              const SizedBox(height: 16),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: AuthGlassInputField(
                                      controller: _ageController,
                                      focusNode: _ageFocus,
                                      isFocused: _ageFocus.hasFocus,
                                      label: 'العمر',
                                      hint: '25',
                                      icon: Icons.cake_outlined,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.right,
                                      keyboardType: TextInputType.number,
                                      errorText: _fieldErrors['age'],
                                      onChanged: (_) => _clearFieldError('age'),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: AuthGlassDropdown<String>(
                                      label: 'الجنس',
                                      icon: Icons.wc_rounded,
                                      value: _selectedGender,
                                      items: const [
                                        DropdownMenuItem(value: 'male', child: Text('ذكر')),
                                        DropdownMenuItem(value: 'female', child: Text('أنثى')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedGender = v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              AuthGlassInputField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                isFocused: _passwordFocus.hasFocus,
                                label: 'كلمة المرور',
                                hint: '••••••••',
                                icon: Icons.lock_outline_rounded,
                                obscureText: !_passwordVisible,
                                errorText: _fieldErrors['password'],
                                onChanged: (_) => _clearFieldError('password'),
                                onSubmitted: (_) => _confirmFocus.requestFocus(),
                                suffixWidget: GestureDetector(
                                  onTap: () => setState(() => _passwordVisible = !_passwordVisible),
                                  child: Icon(
                                    _passwordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white.withOpacity(0.4),
                                    size: 20,
                                  ),
                                ),
                              ),
                              if (_fieldErrors['password'] == null) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    '6 أحرف على الأقل',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.35),
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),

                              AuthGlassInputField(
                                controller: _confirmPasswordController,
                                focusNode: _confirmFocus,
                                isFocused: _confirmFocus.hasFocus,
                                label: 'تأكيد كلمة المرور',
                                hint: '••••••••',
                                icon: Icons.lock_reset_rounded,
                                obscureText: !_confirmPasswordVisible,
                                errorText: _fieldErrors['confirm'],
                                onChanged: (_) => _clearFieldError('confirm'),
                                onSubmitted: (_) => _handleRegister(),
                                suffixWidget: GestureDetector(
                                  onTap: () => setState(
                                      () => _confirmPasswordVisible = !_confirmPasswordVisible),
                                  child: Icon(
                                    _confirmPasswordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white.withOpacity(0.4),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              AuthGlowButton(
                                label: 'إنشاء الحساب',
                                isLoading: _isLoading,
                                onTap: _handleRegister,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'لديك حساب بالفعل؟',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.5),
                                fontFamily: 'Cairo',
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.pop(),
                              child: const Text(
                                'تسجيل الدخول',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: kAuthMint,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

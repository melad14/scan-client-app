import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dr_ray/core/api/api_client.dart';
import 'package:dr_ray/core/services/storage_service.dart';
import 'package:dr_ray/core/services/notification_service.dart';
import 'package:dr_ray/core/utils/constants.dart';
import 'package:dr_ray/core/utils/loading_overlay.dart';
import 'package:dr_ray/core/theme/app_colors.dart';
import 'package:dr_ray/core/theme/theme_provider.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _api.dio.get(Constants.profile);
      if (res.statusCode == 200 && mounted) {
        setState(() => _profile = res.data['data']);
      }
    } on DioException catch (e) {
      if (mounted) {
        if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
          setState(() => _error = 'تعذر الاتصال. تحقق من الإنترنت.');
        } else {
          setState(() => _error = e.response?.data?['message'] ?? 'حدث خطأ أثناء تحميل البيانات.');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'حدث خطأ غير متوقع.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final c = context.colors;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: c.errorBg, borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.logout_rounded, color: c.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text('تسجيل الخروج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                style: TextStyle(fontSize: 14, color: c.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء'))),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('خروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 15))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      setState(() => _isLoggingOut = true);
      try {
        final fcmToken = await NotificationService.currentToken();
        await _api.dio.post(Constants.logout, data: {'fcmToken': fcmToken});
      } catch (_) {}
      await StorageService.clearAll();
      if (mounted) context.go('/login');
    }
  }

  // Google Play requires in-app account deletion for any app with sign-up.
  Future<void> _deleteAccount() async {
    final c = context.colors;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('حذف الحساب نهائياً',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'سيتم حذف اسمك وبريدك ورقم هاتفك والعناوين والأشخاص المحفوظين نهائياً ولا يمكن التراجع.\n\n'
                'سجلات الطلبات الطبية تُحفظ مجهولة الهوية كما يوجب القانون.\n\n'
                'اكتب "حذف" للتأكيد:',
                style: TextStyle(fontFamily: 'Cairo', height: 1.6, fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                onChanged: (_) => setDialogState(() {}),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'حذف',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: controller.text.trim() == 'حذف' ? () => Navigator.of(ctx).pop(true) : null,
              child: Text('حذف نهائياً',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: c.error)),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final res = await _api.dio.delete(Constants.profile);
      if (res.statusCode == 200 && res.data['success'] == true) {
        await StorageService.clearAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم حذف حسابك نهائياً', style: TextStyle(fontFamily: 'Cairo')),
          ));
          context.go('/login');
        }
        return;
      }
      throw Exception(res.data['message'] ?? 'فشل حذف الحساب');
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data?['message'] ?? 'تعذر حذف الحساب. حاول مرة أخرى.',
              style: const TextStyle(fontFamily: 'Cairo')),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(fontFamily: 'Cairo')),
        ));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/');
        }
      },
      child: LoadingOverlay(
        isVisible: _isLoggingOut || _isDeleting,
        message: _isDeleting ? 'جاري حذف الحساب...' : 'جاري تسجيل الخروج...',
        child: Scaffold(
          backgroundColor: c.background,
          body: RefreshIndicator(
            color: c.primary,
            backgroundColor: c.surface,
            onRefresh: _fetchProfile,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header ──────────────────────────────────────────────
                SliverToBoxAdapter(child: _buildHeader(c, isDark)),

                // ── Content ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _isLoading
                      ? _buildLoadingState(c)
                      : _error != null
                          ? _buildErrorState(c)
                          : _buildProfileContent(c, isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorTokens c, bool isDark) {
    final name = _profile?['name'] ?? 'المريض';
    final email = _profile?['email'] ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0A0F1E), const Color(0xFF0F1729)]
              : [const Color(0xFF085041), const Color(0xFF1D9E75)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // ── Top bar ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('حسابي', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              _ThemeToggleButton(),
            ],
          ),
          const SizedBox(height: 24),

          // ── Avatar ──────────────────────────────────────────
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(email, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), fontFamily: 'Inter')),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(AppColorTokens c) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: c.primary)),
            const SizedBox(height: 16),
            Text('جارٍ تحميل البيانات...', style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AppColorTokens c) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: c.errorBg, borderRadius: BorderRadius.circular(18)),
              child: Icon(Icons.wifi_off_rounded, color: c.error, size: 30),
            ),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: c.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _fetchProfile,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(AppColorTokens c, bool isDark) {
    final profile = _profile!;
    final gender = profile['gender'] == 'male' ? 'ذكر' : profile['gender'] == 'female' ? 'أنثى' : null;
    final createdAt = profile['createdAt'] != null
        ? DateTime.tryParse(profile['createdAt'])
        : null;
    final memberSince = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : 'غير محدد';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section: Personal Information ─────────────────
          _sectionTitle(c, 'المعلومات الشخصية', Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _infoCard(c, isDark, [
            _InfoRow(icon: Icons.person_rounded, label: 'الاسم', value: profile['name'] ?? 'غير محدد'),
            _InfoRow(icon: Icons.alternate_email_rounded, label: 'اسم المستخدم', value: profile['username'] ?? 'غير محدد', mono: true),
            _InfoRow(icon: Icons.email_outlined, label: 'البريد الإلكتروني', value: profile['email'] ?? 'غير محدد', mono: true),
          ]),

          const SizedBox(height: 20),

          // ── Section: Additional Details ────────────────────
          _sectionTitle(c, 'بيانات إضافية', Icons.info_outline_rounded),
          const SizedBox(height: 12),
          _infoCard(c, isDark, [
            _InfoRow(icon: Icons.phone_outlined, label: 'رقم الهاتف', value: profile['phone'] ?? 'غير مسجل', mono: true),
            _InfoRow(icon: Icons.cake_outlined, label: 'العمر', value: profile['age']?.toString() ?? 'غير محدد'),
            _InfoRow(icon: Icons.wc_rounded, label: 'الجنس', value: gender ?? 'غير محدد'),
            _InfoRow(icon: Icons.calendar_today_rounded, label: 'عضو منذ', value: memberSince),
          ]),

          const SizedBox(height: 20),

          // ── Section: Saved Profiles ────────────────────
          _sectionTitle(c, 'الملفات المحفوظة لتسهيل الحجز', Icons.bookmark_outline_rounded),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
              boxShadow: isDark ? [] : c.cardShadow,
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile/patients'),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.people_alt_rounded, color: c.primary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('المرضى المحفوظون', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary, fontFamily: 'Cairo')),
                              const SizedBox(height: 3),
                              Text('أفراد العائلة وسجلهم الصحي السريع', style: TextStyle(fontSize: 11, color: c.textSecondary, fontFamily: 'Cairo')),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: c.textMuted, size: 16),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(height: 1, color: c.borderLight),
                ),
                GestureDetector(
                  onTap: () => context.push('/profile/addresses'),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.pin_drop_rounded, color: c.primary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('العناوين المحفوظة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary, fontFamily: 'Cairo')),
                              const SizedBox(height: 3),
                              Text('عناوين الزيارات المنزلية المفضلة', style: TextStyle(fontSize: 11, color: c.textSecondary, fontFamily: 'Cairo')),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: c.textMuted, size: 16),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(height: 1, color: c.borderLight),
                ),
                GestureDetector(
                  onTap: () => context.push('/profile/complaints'),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.warning_amber_rounded, color: c.primary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('شكاواي واعتراضاتي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary, fontFamily: 'Cairo')),
                              const SizedBox(height: 3),
                              Text('متابعة حالة الشكاوى والاعتراضات المرسلة', style: TextStyle(fontSize: 11, color: c.textSecondary, fontFamily: 'Cairo')),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: c.textMuted, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Logout Button ─────────────────────────────────
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: c.errorBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.error.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: c.error, size: 20),
                  const SizedBox(width: 10),
                  Text('تسجيل الخروج', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Legal & account removal (Google Play requirements) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://api.drray-eg.com/privacy'), mode: LaunchMode.externalApplication),
                child: Text('سياسة الخصوصية',
                    style: TextStyle(fontSize: 12, color: c.textMuted, decoration: TextDecoration.underline, fontFamily: 'Cairo')),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('•', style: TextStyle(color: c.textMuted)),
              ),
              GestureDetector(
                onTap: _deleteAccount,
                child: Text('حذف الحساب نهائياً',
                    style: TextStyle(fontSize: 12, color: c.error.withOpacity(0.8), decoration: TextDecoration.underline, fontFamily: 'Cairo')),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppColorTokens c, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: c.primary, size: 18),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
      ],
    );
  }

  Widget _infoCard(AppColorTokens c, bool isDark, List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: isDark ? [] : c.cardShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                    child: Icon(rows[i].icon, color: c.primary, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].label, style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(rows[i].value,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            fontFamily: rows[i].mono ? 'Inter' : 'Cairo',
                          )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(height: 1, color: c.borderLight),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  const _InfoRow({required this.icon, required this.label, required this.value, this.mono = false});
}

// ══════════════════════════════════════════════════════════
//  Theme Toggle Button (reused from home_screen pattern)
// ══════════════════════════════════════════════════════════
class _ThemeToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    return GestureDetector(
      onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            color: Colors.white, size: 18,
          ),
        ),
      ),
    );
  }
}

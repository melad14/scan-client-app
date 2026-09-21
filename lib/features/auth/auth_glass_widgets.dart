import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

// ══════════════════════════════════════════════════════════════════
//  Shared visual language for the auth screens (login + register).
//  Extracted from login_screen.dart so both screens stay identical —
//  register used to be a plain light form that looked like a
//  different app.
//
//  These screens are deliberately dark; the rest of the patient app
//  follows the light theme.
// ══════════════════════════════════════════════════════════════════

const Color kAuthTeal = Color(0xFF1D9E75);
const Color kAuthMint = Color(0xFF2DDBA4);
const Color kAuthDeep = Color(0xFF085041);
const Color kAuthError = Color(0xFFD44245);

/// Dark gradient backdrop with drifting orbs and a faint grid.
class AuthAnimatedBackground extends StatelessWidget {
  final Animation<double> controller;
  final Animation<double> pulseController;
  final Size size;

  const AuthAnimatedBackground({
    super.key,
    required this.controller,
    required this.pulseController,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, pulseController]),
      builder: (_, __) {
        final t = controller.value;
        final p = pulseController.value;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF061A13), Color(0xFF0A2518), Color(0xFF061A13)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.08 + math.sin(t * 2 * math.pi) * 20,
              right: -size.width * 0.15 + math.cos(t * 2 * math.pi) * 10,
              child: _Orb(
                size: size.width * 0.7,
                color: kAuthTeal.withOpacity(0.18 + p * 0.06),
                blurRadius: 80,
              ),
            ),
            Positioned(
              bottom: size.height * 0.15 + math.cos(t * 2 * math.pi) * 25,
              left: -size.width * 0.2 + math.sin(t * 2 * math.pi) * 15,
              child: _Orb(
                size: size.width * 0.6,
                color: kAuthDeep.withOpacity(0.22 + p * 0.04),
                blurRadius: 70,
              ),
            ),
            Positioned(
              top: size.height * 0.4 + math.sin(t * 2 * math.pi + 1) * 30,
              left: size.width * 0.6 + math.cos(t * 2 * math.pi + 1) * 10,
              child: _Orb(
                size: size.width * 0.4,
                color: kAuthMint.withOpacity(0.08 + p * 0.04),
                blurRadius: 60,
              ),
            ),
            CustomPaint(size: size, painter: _GridPainter(opacity: 0.04)),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double blurRadius;

  const _Orb({required this.size, required this.color, required this.blurRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: blurRadius, spreadRadius: blurRadius * 0.3)],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double opacity;
  _GridPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

/// Glowing circular app logo + brand name.
class AuthBrandHeader extends StatelessWidget {
  final String tagline;
  final double logoSize;

  const AuthBrandHeader({super.key, required this.tagline, this.logoSize = 90});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [kAuthMint, kAuthTeal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: kAuthTeal.withOpacity(0.5), blurRadius: 30, spreadRadius: 4),
              BoxShadow(color: kAuthTeal.withOpacity(0.2), blurRadius: 60, spreadRadius: 10),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.medical_services_rounded, color: Colors.white, size: logoSize * 0.49),
            ),
          ),
        ),
        SizedBox(height: logoSize * 0.22),
        Text(
          'Dr Ray',
          style: TextStyle(
            fontSize: logoSize * 0.38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            shadows: const [Shadow(color: kAuthTeal, blurRadius: 20)],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Frosted card that holds an auth form.
class AuthGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AuthGlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(28)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Frosted text field. Pass [errorText] to show the message under the field
/// and turn the border red.
class AuthGlassInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final bool isFocused;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final Widget? suffixWidget;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final String? errorText;

  const AuthGlassInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.isFocused = false,
    this.obscureText = false,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.suffixWidget,
    this.onSubmitted,
    this.onChanged,
    this.keyboardType,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.65),
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? kAuthError.withOpacity(0.9)
                  : isFocused
                      ? kAuthTeal.withOpacity(0.8)
                      : Colors.white.withOpacity(0.12),
              width: hasError || isFocused ? 1.5 : 1,
            ),
            boxShadow: isFocused && !hasError
                ? [BoxShadow(color: kAuthTeal.withOpacity(0.2), blurRadius: 12)]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                textDirection: textDirection,
                textAlign: textAlign,
                onSubmitted: onSubmitted,
                onChanged: onChanged,
                keyboardType: keyboardType,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Cairo'),
                  prefixIcon: Icon(icon,
                      color: hasError
                          ? kAuthError.withOpacity(0.9)
                          : isFocused
                              ? kAuthTeal
                              : Colors.white.withOpacity(0.4),
                      size: 20),
                  suffixIcon: suffixWidget != null
                      ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixWidget)
                      : null,
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFFF9B9D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorText!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFFF9B9D),
                      fontFamily: 'Cairo',
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Frosted dropdown styled to match [AuthGlassInputField].
class AuthGlassDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const AuthGlassDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.65),
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white.withOpacity(0.06),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<T>(
                          value: value,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF0A2518),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white),
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.5)),
                          items: items,
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Glowing primary CTA.
class AuthGlowButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const AuthGlowButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<AuthGlowButton> createState() => _AuthGlowButtonState();
}

class _AuthGlowButtonState extends State<AuthGlowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _pressed
                  ? [const Color(0xFF16755A), kAuthTeal]
                  : [kAuthMint, kAuthTeal, kAuthDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.isLoading
                ? []
                : [
                    BoxShadow(
                      color: kAuthTeal.withOpacity(_pressed ? 0.2 : 0.45),
                      blurRadius: _pressed ? 8 : 20,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: kAuthTeal.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_back_rounded, color: Colors.white.withOpacity(0.8), size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Frosted error banner for messages that aren't tied to one field.
class AuthGlassErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const AuthGlassErrorBanner({super.key, required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kAuthError.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kAuthError.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6E), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFFF9B9D),
                    fontSize: 13,
                    height: 1.4,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, color: Color(0xFFFF6B6E), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

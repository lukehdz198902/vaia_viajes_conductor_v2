import 'package:flutter/material.dart';
import '../config/theme.dart';

class VaiaPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;
  final bool ghost;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? fontSize;

  const VaiaPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.fullWidth = true,
    this.ghost = false,
    this.padding,
    this.height,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    final btn = ElevatedButton(
      onPressed: disabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: ghost ? Colors.transparent : VaiaColors.primary,
        foregroundColor: ghost ? VaiaColors.primary : Colors.white,
        disabledBackgroundColor: ghost ? Colors.transparent : VaiaColors.bgMuted,
        disabledForegroundColor: VaiaColors.textMuted,
        shadowColor: Colors.transparent,
        elevation: ghost ? 0 : 0,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        minimumSize: Size(0, height ?? 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VaiaRadius.md),
          side: ghost ? const BorderSide(color: VaiaColors.primary, width: 1.5) : BorderSide.none,
        ),
      ),
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: ghost ? VaiaColors.primary : Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize ?? 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class VaiaOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool fullWidth;

  const VaiaOutlineButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: VaiaColors.textPrimary,
        side: const BorderSide(color: VaiaColors.border, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class VaiaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool elevated;
  final BorderRadius? radius;

  const VaiaCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.elevated = false,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = this.radius ?? BorderRadius.circular(VaiaRadius.lg);
    return Material(
      color: color ?? VaiaColors.surface,
      borderRadius: radius,
      elevation: elevated ? 2 : 0,
      shadowColor: Colors.black.withOpacity(0.04),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class VaiaBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;
  final EdgeInsetsGeometry? padding;

  const VaiaBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.filled = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? VaiaColors.primary;
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? c.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(VaiaRadius.pill),
        border: filled ? null : Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class VaiaLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;

  const VaiaLogo({
    super.key,
    this.size = 48,
    this.showText = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? VaiaColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: VaiaColors.primaryGradient,
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: [
              BoxShadow(color: c.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(
            Icons.local_taxi_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 10),
          Text(
            'Vaia',
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              color: c,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class VaiaStatusDot extends StatelessWidget {
  final bool online;
  final double size;

  const VaiaStatusDot({super.key, required this.online, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: online ? VaiaColors.onlineGreen : VaiaColors.offlineRed,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (online ? VaiaColors.onlineGreen : VaiaColors.offlineRed).withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class VaiaTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final bool autofocus;
  final int? maxLength;
  final int maxLines;
  final bool enabled;

  const VaiaTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      autofocus: autofocus,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      enabled: enabled,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: suffixIcon,
        counterText: '',
      ),
    );
  }
}
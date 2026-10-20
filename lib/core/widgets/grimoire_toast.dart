import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/grimoire_theme.dart';

enum GrimoireToastType {
  success,
  info,
  warning,
  error,
}

/// Sistema de notificaciones flotantes elegantes para Grimoire Studio.
/// Sustituye a las barras fijas inferiores (SnackBars tradicionales)
/// por tarjetas flotantes estilizadas con estética Dark Fantasy / High-Tech.
class GrimoireToast {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    GrimoireToastType type = GrimoireToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final defaultDuration = actionLabel != null
        ? const Duration(seconds: 6)
        : (type == GrimoireToastType.error
            ? const Duration(seconds: 5)
            : const Duration(milliseconds: 3500));

    final effectiveDuration = duration ?? defaultDuration;

    messenger.showSnackBar(
      snackBar(
        context: context,
        message: message,
        title: title,
        type: type,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: effectiveDuration,
        icon: icon,
      ),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    IconData? icon,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: GrimoireToastType.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      icon: icon,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    IconData? icon,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: GrimoireToastType.error,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      icon: icon,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    IconData? icon,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: GrimoireToastType.info,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      icon: icon,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    IconData? icon,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: GrimoireToastType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      icon: icon,
    );
  }

  static SnackBar snackBar({
    required BuildContext context,
    required String message,
    String? title,
    GrimoireToastType type = GrimoireToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    IconData? icon,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final toastWidth = math.min(540.0, screenWidth > 64 ? screenWidth - 48 : screenWidth);

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      width: toastWidth,
      duration: duration,
      showCloseIcon: false,
      content: GrimoireToastCard(
        message: message,
        title: title,
        type: type,
        actionLabel: actionLabel,
        onAction: onAction,
        icon: icon,
      ),
    );
  }
}

class GrimoireToastCard extends StatelessWidget {
  final String message;
  final String? title;
  final GrimoireToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  const GrimoireToastCard({
    super.key,
    required this.message,
    this.title,
    this.type = GrimoireToastType.info,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  Color get _accentColor {
    switch (type) {
      case GrimoireToastType.success:
        return GrimoireTheme.accentEmerald;
      case GrimoireToastType.error:
        return GrimoireTheme.accentPink;
      case GrimoireToastType.warning:
        return GrimoireTheme.accentAmber;
      case GrimoireToastType.info:
        return GrimoireTheme.accentCyan;
    }
  }

  IconData get _defaultIcon {
    switch (type) {
      case GrimoireToastType.success:
        return Icons.check_circle_rounded;
      case GrimoireToastType.error:
        return Icons.error_outline_rounded;
      case GrimoireToastType.warning:
        return Icons.warning_amber_rounded;
      case GrimoireToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final displayIcon = icon ?? _defaultIcon;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131724), // Superficie flotante oscura
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono con halo brillante
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              displayIcon,
              color: accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          // Contenido de texto
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.trim().isNotEmpty) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    color: GrimoireTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Botón de acción opcional
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onAction!();
                },
                borderRadius: BorderRadius.circular(8),
                hoverColor: accent.withValues(alpha: 0.12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel!,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: accent,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // Botón cerrar
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              borderRadius: BorderRadius.circular(16),
              hoverColor: Colors.white10,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: GrimoireTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

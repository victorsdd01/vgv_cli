import 'package:flutter/material.dart';
import '../../../application/generated/l10n.dart';

class AppDialogs {
  AppDialogs._();

  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
    IconData? icon,
  }) async {
    final ThemeData theme = Theme.of(context);
    final S translation = S.of(context);
    
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: icon != null
            ? Icon(icon, color: confirmColor ?? theme.colorScheme.primary, size: 48)
            : null,
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelText ?? translation.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? theme.colorScheme.primary,
              foregroundColor: confirmColor != null 
                  ? theme.colorScheme.onError 
                  : theme.colorScheme.onPrimary,
            ),
            child: Text(confirmText ?? translation.confirm),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  static Future<bool> showLogoutConfirmation({
    required BuildContext context,
    String? title,
    String? message,
  }) {
    final S translation = S.of(context);
    
    return showConfirmation(
      context: context,
      title: title ?? translation.logout,
      message: message ?? translation.logoutConfirmationMessage,
      confirmText: translation.logout,
      confirmColor: Theme.of(context).colorScheme.error,
      icon: Icons.logout,
    );
  }

  static Future<bool> showDeleteConfirmation({
    required BuildContext context,
    required String itemName,
    String? title,
    String? message,
  }) {
    final S translation = S.of(context);
    
    return showConfirmation(
      context: context,
      title: title ?? translation.delete,
      message: message ?? translation.deleteConfirmationMessage(itemName),
      confirmText: translation.delete,
      confirmColor: Theme.of(context).colorScheme.error,
      icon: Icons.delete_outline,
    );
  }

  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    IconData? icon,
  }) async {
    final ThemeData theme = Theme.of(context);
    final S translation = S.of(context);
    
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: icon != null
            ? Icon(icon, color: theme.colorScheme.primary, size: 48)
            : null,
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(buttonText ?? translation.accept),
          ),
        ],
      ),
    );
  }

  static Future<void> showError({
    required BuildContext context,
    required String message,
    String? title,
    String? buttonText,
  }) {
    final S translation = S.of(context);
    
    return showInfo(
      context: context,
      title: title ?? translation.error,
      message: message,
      buttonText: buttonText ?? translation.accept,
      icon: Icons.error_outline,
    );
  }

  static Future<void> showSuccess({
    required BuildContext context,
    required String message,
    String? title,
    String? buttonText,
  }) {
    final S translation = S.of(context);
    
    return showInfo(
      context: context,
      title: title ?? translation.success,
      message: message,
      buttonText: buttonText ?? translation.accept,
      icon: Icons.check_circle_outline,
    );
  }

  static void showLoading({
    required BuildContext context,
    String? message,
  }) {
    final S translation = S.of(context);
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Text(message ?? translation.loading),
            ],
          ),
        ),
      ),
    );
  }

  static void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  static Future<T?> showOptionsBottomSheet<T>({
    required BuildContext context,
    required String title,
    required List<OptionItem<T>> options,
  }) async {
    final ThemeData theme = Theme.of(context);
    
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            ...options.map((OptionItem<T> option) => ListTile(
              leading: option.icon != null
                  ? Icon(option.icon, color: option.color)
                  : null,
              title: Text(option.title, style: TextStyle(color: option.color)),
              subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
              onTap: () => Navigator.of(bottomSheetContext).pop(option.value),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class OptionItem<T> {
  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;

  const OptionItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
  });
}

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

enum BellPlatform { windows, android, ios }

/// Explicit platform seam set by the root app widget.
///
/// Material's `Theme.of` cannot be used here: the Windows shell runs inside a
/// `FluentApp`, which has no Material `Theme` ancestor.
class AdaptiveScope extends InheritedWidget {
  const AdaptiveScope({
    required this.platform,
    required super.child,
    super.key,
  });

  final BellPlatform platform;

  @override
  bool updateShouldNotify(AdaptiveScope oldWidget) =>
      platform != oldWidget.platform;
}

BellPlatform bellPlatform(BuildContext context) {
  final scope = context.dependOnInheritedWidgetOfExactType<AdaptiveScope>();
  return scope?.platform ??
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => BellPlatform.ios,
        TargetPlatform.android => BellPlatform.android,
        _ => BellPlatform.windows,
      };
}

enum AdaptiveIcon { add, addClass, classes, more, delete, edit }

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return switch (bellPlatform(context)) {
      BellPlatform.windows => fluent.FilledButton(
        onPressed: onPressed,
        child: Text(label),
      ),
      BellPlatform.ios => cupertino.CupertinoButton.filled(
        onPressed: onPressed,
        child: Text(label),
      ),
      BellPlatform.android => material.FilledButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    };
  }
}

class AdaptiveIconButton extends StatelessWidget {
  const AdaptiveIconButton({
    required this.iconDescription,
    required this.onPressed,
    required this.icon,
    super.key,
  });

  final String iconDescription;
  final VoidCallback onPressed;
  final AdaptiveIcon icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: iconDescription,
      button: true,
      child: switch (bellPlatform(context)) {
        BellPlatform.windows => fluent.IconButton(
          icon: Icon(_fluentIcon(icon)),
          onPressed: onPressed,
        ),
        BellPlatform.ios => cupertino.CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Icon(_cupertinoIcon(icon)),
        ),
        BellPlatform.android => material.IconButton(
          tooltip: iconDescription,
          icon: Icon(_materialIcon(icon)),
          onPressed: onPressed,
        ),
      },
    );
  }

  static IconData _fluentIcon(AdaptiveIcon i) => switch (i) {
    AdaptiveIcon.add => fluent.FluentIcons.add,
    AdaptiveIcon.addClass => fluent.FluentIcons.add_group,
    AdaptiveIcon.classes => fluent.FluentIcons.people,
    AdaptiveIcon.more => fluent.FluentIcons.more,
    AdaptiveIcon.delete => fluent.FluentIcons.delete,
    AdaptiveIcon.edit => fluent.FluentIcons.edit,
  };

  static IconData _cupertinoIcon(AdaptiveIcon i) => switch (i) {
    AdaptiveIcon.add => cupertino.CupertinoIcons.add,
    AdaptiveIcon.addClass => cupertino.CupertinoIcons.person_badge_plus,
    AdaptiveIcon.classes => cupertino.CupertinoIcons.list_bullet,
    AdaptiveIcon.more => cupertino.CupertinoIcons.ellipsis,
    AdaptiveIcon.delete => cupertino.CupertinoIcons.trash,
    AdaptiveIcon.edit => cupertino.CupertinoIcons.pencil,
  };

  static IconData _materialIcon(AdaptiveIcon i) => switch (i) {
    AdaptiveIcon.add => material.Icons.add,
    AdaptiveIcon.addClass => material.Icons.group_add_outlined,
    AdaptiveIcon.classes => material.Icons.swap_horiz,
    AdaptiveIcon.more => material.Icons.more_vert,
    AdaptiveIcon.delete => material.Icons.delete_outline,
    AdaptiveIcon.edit => material.Icons.edit_outlined,
  };
}

class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    required this.label,
    required this.controller,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: label,
      child: switch (bellPlatform(context)) {
        BellPlatform.windows => fluent.InfoLabel(
          label: label,
          child: fluent.TextBox(controller: controller, autofocus: autofocus),
        ),
        BellPlatform.ios => cupertino.CupertinoTextField(
          placeholder: label,
          controller: controller,
          autofocus: autofocus,
          padding: const EdgeInsets.all(12),
        ),
        BellPlatform.android => material.TextField(
          controller: controller,
          autofocus: autofocus,
          decoration: material.InputDecoration(
            labelText: label,
            border: const material.OutlineInputBorder(),
          ),
        ),
      },
    );
  }
}

class AdaptiveAvatar extends StatelessWidget {
  const AdaptiveAvatar({required this.initials, super.key});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF315AA4).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}

class AdaptiveTile extends StatelessWidget {
  const AdaptiveTile({
    required this.title,
    required this.semanticLabel,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String semanticLabel;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: switch (bellPlatform(context)) {
        BellPlatform.windows => fluent.ListTile(
          leading: leading,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: trailing,
          onPressed: onTap,
        ),
        BellPlatform.ios => cupertino.CupertinoListTile(
          leading: leading,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: trailing,
          onTap: onTap,
        ),
        BellPlatform.android => material.ListTile(
          leading: leading,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: trailing,
          onTap: onTap,
        ),
      },
    );
  }
}

class AdaptiveSelectableTile extends StatelessWidget {
  const AdaptiveSelectableTile({
    required this.title,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: label,
      child: switch (bellPlatform(context)) {
        BellPlatform.windows => fluent.ListTile.selectable(
          selected: selected,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: trailing,
          onPressed: onTap,
        ),
        BellPlatform.ios => Container(
          color: selected
              ? const Color(0xFF315AA4).withValues(alpha: 0.08)
              : null,
          child: cupertino.CupertinoListTile(
            title: Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: subtitle != null ? Text(subtitle!) : null,
            trailing: trailing,
            onTap: onTap,
          ),
        ),
        BellPlatform.android => material.ListTile(
          selected: selected,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: trailing,
          onTap: onTap,
        ),
      },
    );
  }
}

class AdaptiveCommandItem {
  const AdaptiveCommandItem({
    required this.description,
    required this.icon,
    required this.onPressed,
    this.key,
  });

  final Key? key;
  final String description;
  final AdaptiveIcon icon;
  final VoidCallback onPressed;
}

class AdaptiveCommandBar extends StatelessWidget {
  const AdaptiveCommandBar({
    required this.label,
    required this.items,
    super.key,
  });

  final String label;
  final List<AdaptiveCommandItem> items;

  @override
  Widget build(BuildContext context) {
    return switch (bellPlatform(context)) {
      BellPlatform.windows => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerRight,
        child: fluent.CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            for (final item in items)
              fluent.CommandBarButton(
                key: item.key,
                icon: Icon(AdaptiveIconButton._fluentIcon(item.icon)),
                label: Text(item.description),
                onPressed: item.onPressed,
              ),
          ],
        ),
      ),
      BellPlatform.ios => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                cupertino.CupertinoButton(
                  key: item.key,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: item.onPressed,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AdaptiveIconButton._cupertinoIcon(item.icon),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(item.description),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      BellPlatform.android => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                material.TextButton.icon(
                  key: item.key,
                  onPressed: item.onPressed,
                  icon: Icon(AdaptiveIconButton._materialIcon(item.icon)),
                  label: Text(item.description),
                ),
            ],
          ),
        ),
      ),
    };
  }
}

class AdaptiveDialog extends StatelessWidget {
  const AdaptiveDialog({
    required this.title,
    required this.content,
    required this.cancel,
    required this.confirm,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  final String title;
  final Widget content;
  final String cancel;
  final String confirm;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return switch (bellPlatform(context)) {
      BellPlatform.windows => fluent.ContentDialog(
        title: Text(title),
        content: content,
        actions: [
          fluent.Button(onPressed: onCancel, child: Text(cancel)),
          fluent.FilledButton(
            key: const Key('dialog-submit'),
            onPressed: onConfirm,
            child: Text(confirm),
          ),
        ],
      ),
      BellPlatform.ios => cupertino.CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: content,
        ),
        actions: [
          cupertino.CupertinoDialogAction(
            onPressed: onCancel,
            child: Text(cancel),
          ),
          cupertino.CupertinoDialogAction(
            key: const Key('dialog-submit'),
            isDefaultAction: true,
            onPressed: onConfirm,
            child: Text(confirm),
          ),
        ],
      ),
      BellPlatform.android => material.AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          material.TextButton(onPressed: onCancel, child: Text(cancel)),
          material.FilledButton(
            key: const Key('dialog-submit'),
            onPressed: onConfirm,
            child: Text(confirm),
          ),
        ],
      ),
    };
  }
}

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final String title;
  final Widget body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return switch (bellPlatform(context)) {
      BellPlatform.windows => fluent.ScaffoldPage(
        header: fluent.PageHeader(title: Text(title), commandBar: action),
        content: body,
      ),
      BellPlatform.ios => cupertino.CupertinoPageScaffold(
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(title),
          trailing: action,
        ),
        child: body,
      ),
      BellPlatform.android => material.Scaffold(
        appBar: material.AppBar(title: Text(title), actions: [?action]),
        body: body,
      ),
    };
  }
}

Future<T?> showAdaptiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return switch (bellPlatform(context)) {
    BellPlatform.windows => fluent.showDialog<T>(
      context: context,
      builder: builder,
    ),
    BellPlatform.ios => cupertino.showCupertinoDialog<T>(
      context: context,
      builder: builder,
    ),
    BellPlatform.android => material.showDialog<T>(
      context: context,
      builder: builder,
    ),
  };
}

/// A one-field prompt whose controller is owned by the dialog state, so it is
/// disposed only after the route is gone (not under a still-animating field).
Future<String?> showAdaptivePrompt({
  required BuildContext context,
  required String title,
  required String submitLabel,
  required String label,
  Key? fieldKey,
  String? initialText,
}) {
  return showAdaptiveDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      submitLabel: submitLabel,
      label: label,
      fieldKey: fieldKey,
      initialText: initialText,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.submitLabel,
    required this.label,
    this.fieldKey,
    this.initialText,
  });

  final String title;
  final String submitLabel;
  final String label;
  final Key? fieldKey;
  final String? initialText;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveDialog(
      title: widget.title,
      content: AdaptiveTextField(
        key: widget.fieldKey,
        label: widget.label,
        controller: _controller,
        autofocus: true,
      ),
      cancel: 'Cancel',
      confirm: widget.submitLabel,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () => Navigator.of(context).pop(_controller.text),
    );
  }
}

Future<void> showAdaptiveNotice(
  BuildContext context,
  String title,
  String message,
) {
  return showAdaptiveDialog<void>(
    context: context,
    builder: (ctx) => AdaptiveDialog(
      title: title,
      content: Text(message),
      cancel: 'Dismiss',
      confirm: 'OK',
      onCancel: () => Navigator.of(ctx).pop(),
      onConfirm: () => Navigator.of(ctx).pop(),
    ),
  );
}

Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required String title,
  required List<(T, String)> options,
}) {
  return switch (bellPlatform(context)) {
    BellPlatform.ios => cupertino.showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => cupertino.CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final opt in options)
            cupertino.CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(opt.$1),
              child: Text(opt.$2),
            ),
        ],
        cancelButton: cupertino.CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    ),
    _ => showAdaptiveDialog<T>(
      context: context,
      builder: (ctx) => AdaptiveDialog(
        title: title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in options)
              AdaptiveButton(
                label: opt.$2,
                onPressed: () => Navigator.of(ctx).pop(opt.$1),
              ),
          ],
        ),
        cancel: 'Cancel',
        confirm: 'Close',
        onCancel: () => Navigator.of(ctx).pop(),
        onConfirm: () => Navigator.of(ctx).pop(),
      ),
    ),
  };
}

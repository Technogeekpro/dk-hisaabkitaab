import 'package:flutter/material.dart';

import 'theme.dart';

/// White rounded card with a hairline border.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// A card holding rows separated by inset dividers.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children, this.indent = 68});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(indent: indent),
          children[i],
        ],
      ],
    ),
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (leading != null) ...[leading!, const SizedBox(width: 4)],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.pageTitle),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: AppText.label),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 10, left: 2),
    child: SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

/// Small grey label above a group of settings.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: Text(text, style: AppText.label),
  );
}

/// 40×40 rounded square holding an emoji or an icon.
class LeadingBadge extends StatelessWidget {
  const LeadingBadge({
    super.key,
    this.emoji,
    this.icon,
    this.background = AppColors.fill,
    this.foreground = AppColors.text,
  });

  final String? emoji;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: emoji != null
        ? Text(emoji!, style: const TextStyle(fontSize: 20))
        : Icon(icon, size: 20, color: foreground),
  );
}

/// One row in a grouped list: badge, title/subtitle, trailing content.
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowTitle,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    ),
  );
}

/// Label over a value, used inside cards.
class MetricBlock extends StatelessWidget {
  const MetricBlock({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.label, maxLines: 1),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, style: AppText.metric.copyWith(color: valueColor)),
      ),
    ],
  );
}

class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.background = AppColors.positiveSoft,
    this.foreground = AppColors.positive,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: foreground,
        fontFeatures: tabularFigures,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.receipt_long_outlined,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    child: Column(
      children: [
        Icon(icon, size: 28, color: AppColors.textFaint),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: AppText.label),
      ],
    ),
  );
}

/// Red background revealed when swiping a row to delete it.
class DeleteBackground extends StatelessWidget {
  const DeleteBackground({super.key});

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.negative,
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    child: const Icon(Icons.delete_outline, color: Colors.white),
  );
}

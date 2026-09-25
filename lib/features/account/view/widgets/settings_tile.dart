import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SettingTile extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final String title;
  final String? subtitle;
  final Icon leadingIcon;
  final Icon? trailingIcon;
  final VoidCallback? onTap;
  final Widget? trailingWidget;
  final Color? leadingIconColor;
  final Color? leadingIconBackgroundColor;
  final Color? tileColor;
  final Color? titleColor;
  final String? infoText;

  const SettingTile({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.title,
    this.subtitle,
    required this.leadingIcon,
    this.trailingIcon,
    this.onTap,
    this.trailingWidget,
    this.leadingIconColor,
    this.leadingIconBackgroundColor,
    this.tileColor,
    this.titleColor,
    this.infoText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // One wrapper handles the disabled look for every part of the row (icon,
    // title, subtitle, chevron) without threading a colour through each.
    final row = Column(
      children: [
        if (!isFirst)
          Padding(
            // Breathing room around the divider so grouped tiles don't
            // read as one cramped block.
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Divider(
              height: 1,
              color: Theme.of(context).colorScheme.secondaryContainer,
              indent: 18,
              endIndent: 28,
              thickness: 0.8,
            ),
          ),
        Material(
          color: Colors.transparent,
          child: ListTile(
            minVerticalPadding: 10,
            tileColor: tileColor ?? Colors.transparent,
            // Use the same Outfit title role as the Academics hub. The
            // previous bodyLarge role rendered these options at regular
            // weight while academic rows were semi-bold, which made the two
            // menus look like different type systems.
            titleTextStyle: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: titleColor),
            // Plain line icon, no chip behind it: a filled rounded square
            // behind every glyph reads as heavy at row height, while the
            // bare stroke matches the rest of the profile menu.
            leading: leadingIconBackgroundColor == null
                ? Icon(
                    leadingIcon.icon,
                    size: 20,
                    color: leadingIconColor ?? colorScheme.onSurfaceVariant,
                  )
                : Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: leadingIconBackgroundColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      leadingIcon.icon,
                      size: 20,
                      color: leadingIconColor ?? colorScheme.onSurfaceVariant,
                    ),
                  ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(title),
                    if (infoText != null)
                      Tooltip(
                        message: infoText!,
                        triggerMode: TooltipTriggerMode.tap,
                        showDuration: const Duration(seconds: 5),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(
                            LucideIcons.circleHelp,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            // Every row is a link, so a chevron is the default affordance;
            // pass trailingWidget to override (the Logout row has none).
            trailing:
                trailingWidget ??
                trailingIcon ??
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            onTap: onTap,
          ),
        ),
      ],
    );

    return row;
  }
}

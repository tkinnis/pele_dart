import 'package:flutter/material.dart';

/// Descriptor for a single segment in a [MacSegmentedControl].
class MacSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? tooltip;

  const MacSegment({
    required this.value,
    required this.label,
    this.icon,
    this.tooltip,
  });
}

/// Native macOS-style (`NSSegmentedControl`) desktop segmented control.
///
/// Unlike Material 3's mobile `SegmentedButton` (which uses stadium pills,
/// inserts a shifting checkmark icon, and adds tall touch padding), this widget
/// renders a compact recessed rounded-rectangle track with an elevated active
/// segment pill and subtle inter-segment dividers.
class MacSegmentedControl<T> extends StatelessWidget {
  final List<MacSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;
  final double fontSize;
  final bool expand;

  const MacSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 26,
    this.fontSize = 11.5,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final trackColor =
        isDark
            ? const Color(0xFF181B22)
            : cs.surfaceContainerHighest.withValues(alpha: 0.85);
    final activePillColor =
        isDark ? const Color(0xFF323846) : const Color(0xFFFFFFFF);
    final activeBorderColor =
        isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.12);
    final trackBorderColor =
        isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.10);

    final children = <Widget>[];
    final selectedIdx = segments.indexWhere((s) => s.value == selected);

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isSelected = seg.value == selected;

      if (i > 0) {
        final hideDivider = (i == selectedIdx) || (i - 1 == selectedIdx);
        children.add(
          Container(
            width: 1,
            height: height - 10,
            color:
                hideDivider
                    ? Colors.transparent
                    : cs.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.45),
          ),
        );
      }

      Widget pill = _MacSegmentButton(
        label: seg.label,
        icon: seg.icon,
        tooltip: seg.tooltip,
        isSelected: isSelected,
        activePillColor: activePillColor,
        activeBorderColor: activeBorderColor,
        fontSize: fontSize,
        onTap: () {
          if (!isSelected) {
            onChanged(seg.value);
          }
        },
      );

      if (expand) {
        pill = Expanded(child: pill);
      }
      children.add(pill);
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: trackBorderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _MacSegmentButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final String? tooltip;
  final bool isSelected;
  final Color activePillColor;
  final Color activeBorderColor;
  final double fontSize;
  final VoidCallback onTap;

  const _MacSegmentButton({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.activePillColor,
    required this.activeBorderColor,
    required this.fontSize,
    required this.onTap,
  });

  @override
  State<_MacSegmentButton> createState() => _MacSegmentButtonState();
}

class _MacSegmentButtonState extends State<_MacSegmentButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fgColor =
        widget.isSelected
            ? cs.onSurface
            : (_hovering
                ? cs.onSurface.withValues(alpha: 0.92)
                : cs.onSurfaceVariant);

    Widget content = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:
                widget.isSelected
                    ? widget.activePillColor
                    : (_hovering
                        ? cs.onSurface.withValues(alpha: 0.05)
                        : Colors.transparent),
            borderRadius: BorderRadius.circular(4.5),
            border:
                widget.isSelected
                    ? Border.all(color: widget.activeBorderColor, width: 0.8)
                    : null,
            boxShadow:
                widget.isSelected
                    ? <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 2,
                        offset: const Offset(0, 0.5),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 13.5, color: fgColor),
                const SizedBox(width: 5),
              ],
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }
    return content;
  }
}

/// Item descriptor for [MacPopupButton].
class MacPopupItem<T> {
  final T value;
  final String label;
  final Color? dotColor;
  final Color? dotBorderColor;

  const MacPopupItem({
    required this.value,
    required this.label,
    this.dotColor,
    this.dotBorderColor,
  });
}

/// Native macOS-style (`NSPopUpButton`) compact popup menu button.
class MacPopupButton<T> extends StatefulWidget {
  final String? prefixLabel;
  final T value;
  final List<MacPopupItem<T>> items;
  final ValueChanged<T> onChanged;
  final String? tooltip;
  final double height;

  const MacPopupButton({
    super.key,
    this.prefixLabel,
    required this.value,
    required this.items,
    required this.onChanged,
    this.tooltip,
    this.height = 26,
  });

  @override
  State<MacPopupButton<T>> createState() => _MacPopupButtonState<T>();
}

class _MacPopupButtonState<T> extends State<MacPopupButton<T>> {
  bool _hovering = false;

  Future<void> _openMenu() async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset(0, box.size.height + 2), ancestor: overlay),
        box.localToGlobal(
          box.size.bottomRight(const Offset(0, 2)),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<T>(
      context: context,
      position: position,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.8),
        ),
      ),
      items: <PopupMenuEntry<T>>[
        for (final item in widget.items)
          PopupMenuItem<T>(
            value: item.value,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 16,
                  child:
                      item.value == widget.value
                          ? const Icon(Icons.check, size: 13)
                          : null,
                ),
                if (item.dotColor != null) ...<Widget>[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: item.dotColor,
                      shape: BoxShape.circle,
                      border:
                          item.dotBorderColor != null
                              ? Border.all(
                                color: item.dotBorderColor!,
                                width: 1.8,
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        item.value == widget.value
                            ? FontWeight.w600
                            : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (selected != null && selected != widget.value) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeItem = widget.items.firstWhere(
      (i) => i.value == widget.value,
      orElse: () => widget.items.first,
    );

    final bgColor =
        isDark
            ? (_hovering ? const Color(0xFF323846) : const Color(0xFF262A34))
            : (_hovering ? cs.surfaceContainerHighest : cs.surfaceContainerLow);
    final borderColor =
        isDark
            ? Colors.white.withValues(alpha: 0.13)
            : Colors.black.withValues(alpha: 0.14);

    Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openMenu,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.only(left: 9, right: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (activeItem.dotColor != null) ...<Widget>[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: activeItem.dotColor,
                    shape: BoxShape.circle,
                    border:
                        activeItem.dotBorderColor != null
                            ? Border.all(
                              color: activeItem.dotBorderColor!,
                              width: 1.8,
                            )
                            : null,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                activeItem.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.unfold_more, size: 13, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    if (widget.prefixLabel == null) return button;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.prefixLabel!,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 5),
        button,
      ],
    );
  }
}

/// Compact rounded-square (`5px` radius) macOS toolbar icon button.
class MacIconButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool isActive;

  const MacIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.size = 26,
    this.iconSize = 15,
    this.isActive = false,
  });

  @override
  State<MacIconButton> createState() => _MacIconButtonState();
}

class _MacIconButtonState extends State<MacIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;

    Color bg = Colors.transparent;
    if (widget.isActive) {
      bg = cs.primary.withValues(alpha: 0.18);
    } else if (_hovering && enabled) {
      bg = cs.onSurface.withValues(alpha: 0.08);
    }

    Widget btn = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(5),
            border:
                widget.isActive
                    ? Border.all(
                      color: cs.primary.withValues(alpha: 0.45),
                      width: 1,
                    )
                    : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color:
                !enabled
                    ? cs.onSurfaceVariant.withValues(alpha: 0.38)
                    : (widget.isActive ? cs.primary : cs.onSurfaceVariant),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

/// Compact `26px` macOS desktop push button (`6px` radius) with optional icon.
class MacToolbarButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool primary;
  final double height;

  const MacToolbarButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.tooltip,
    this.primary = false,
    this.height = 26,
  });

  @override
  State<MacToolbarButton> createState() => _MacToolbarButtonState();
}

class _MacToolbarButtonState extends State<MacToolbarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final enabled = widget.onPressed != null;

    final Color bg;
    final Color fg;
    final Color border;

    if (widget.primary) {
      bg =
          _hovering && enabled
              ? cs.primary.withValues(alpha: 0.9)
              : cs.primary.withValues(alpha: 0.8);
      fg = cs.onPrimary;
      border = cs.primary;
    } else {
      bg =
          isDark
              ? (_hovering && enabled
                  ? const Color(0xFF323846)
                  : const Color(0xFF262A34))
              : (_hovering && enabled
                  ? cs.surfaceContainerHighest
                  : cs.surfaceContainerLow);
      fg = enabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.45);
      border =
          isDark
              ? Colors.white.withValues(alpha: 0.13)
              : Colors.black.withValues(alpha: 0.14);
    }

    Widget btn = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 13.5, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

/// Compact `26px` macOS desktop toggle button (replaces Material `FilterChip`).
class MacToggleButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final String? tooltip;
  final double height;

  const MacToggleButton({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onChanged,
    this.tooltip,
    this.height = 26,
  });

  @override
  State<MacToggleButton> createState() => _MacToggleButtonState();
}

class _MacToggleButtonState extends State<MacToggleButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg =
        widget.selected
            ? cs.primary.withValues(alpha: isDark ? 0.22 : 0.15)
            : (isDark
                ? (_hovering
                    ? const Color(0xFF323846)
                    : const Color(0xFF262A34))
                : (_hovering
                    ? cs.surfaceContainerHighest
                    : cs.surfaceContainerLow));
    final border =
        widget.selected
            ? cs.primary.withValues(alpha: 0.65)
            : (isDark
                ? Colors.white.withValues(alpha: 0.13)
                : Colors.black.withValues(alpha: 0.14));
    final fg = widget.selected ? cs.primary : cs.onSurface;

    Widget btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!widget.selected),
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                widget.icon ??
                    (widget.selected
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank),
                size: 13,
                color: fg,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

/// Compact desktop horizontal slider for `36px` toolbars.
class MacCompactSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double width;

  const MacCompactSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.width = 96,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 24,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }
}

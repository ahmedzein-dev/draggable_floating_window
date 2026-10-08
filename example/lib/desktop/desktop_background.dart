import 'package:flutter/material.dart';

import '../app/window_launcher.dart';

/// The wallpaper behind the windows, with shortcuts that open each window
/// type.
class DesktopBackground extends StatelessWidget {
  const DesktopBackground({super.key, required this.launcher});

  final WindowLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dark = colors.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? <Color>[
                  const Color(0xFF0B1022),
                  Color.lerp(const Color(0xFF10172E), colors.primary, 0.25)!,
                  const Color(0xFF071A24),
                ]
              : <Color>[
                  Color.lerp(Colors.white, colors.primary, 0.18)!,
                  const Color(0xFFF4F6FB),
                  Color.lerp(Colors.white, colors.tertiary, 0.2)!,
                ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Soft glows, tinted with the accent color.
          Positioned(
            right: -120,
            top: -140,
            child: _Glow(color: colors.primary, size: 520),
          ),
          Positioned(
            left: 160,
            bottom: -220,
            child: _Glow(color: colors.tertiary, size: 560),
          ),
          // Pinned to the full height, so the icons flow into another column
          // when the window is short instead of overflowing.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                direction: Axis.vertical,
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  _DesktopIcon(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'New note',
                    onOpen: launcher.openNote,
                  ),
                  _DesktopIcon(
                    icon: Icons.checklist_rounded,
                    label: 'Tasks',
                    onOpen: launcher.openTasks,
                  ),
                  _DesktopIcon(
                    icon: Icons.calculate_outlined,
                    label: 'Calculator',
                    onOpen: launcher.openCalculator,
                  ),
                  _DesktopIcon(
                    icon: Icons.layers_outlined,
                    label: 'Activity',
                    onOpen: launcher.openActivity,
                  ),
                  _DesktopIcon(
                    icon: Icons.tune_rounded,
                    label: 'Settings',
                    onOpen: launcher.openSettings,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopIcon extends StatefulWidget {
  const _DesktopIcon({
    required this.icon,
    required this.label,
    required this.onOpen,
  });

  final IconData icon;
  final String label;
  final VoidCallback onOpen;

  @override
  State<_DesktopIcon> createState() => _DesktopIconState();
}

class _DesktopIconState extends State<_DesktopIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dark = colors.brightness == Brightness.dark;
    final Color foreground = dark ? Colors.white : colors.onSurface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? foreground.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: dark
                      ? const <Shadow>[
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

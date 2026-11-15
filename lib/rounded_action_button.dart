import 'package:flutter/material.dart';
import 'brigade_map_detail.dart';

class RoundedActionButton extends StatelessWidget {
  final VoidCallback? onPressed;

  final Widget child;

  final double size;

  final Color color;

  final Color disabledColor;

  final double elevation;

  final bool navigateToProfile;

  final String? alertId;

  final String? userId;

  const RoundedActionButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.size = 72.0,
    this.color = Colors.red,
    this.disabledColor = const Color(0xFFBDBDBD),
    this.elevation = 6.0,
    this.navigateToProfile = false,
    this.alertId,
    this.userId,
  })  : assert(!navigateToProfile || (navigateToProfile && alertId != null),
            'alertId must be provided when navigateToProfile is true'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null || navigateToProfile;
    VoidCallback? effectiveOnPressed = onPressed;
    if (effectiveOnPressed == null && navigateToProfile) {
      effectiveOnPressed = () {
        if (alertId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BrigadeMapDetailScreen(
              alertId: alertId!,
              userId: userId,
            ),
          ),
        );
      };
    }

    return Material(
      color: enabled ? color : disabledColor,
      elevation: enabled ? elevation : 0,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? effectiveOnPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: DefaultTextStyle(
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white70,
                fontSize: 12,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: enabled ? Colors.white : Colors.white70,
                  size: 28,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

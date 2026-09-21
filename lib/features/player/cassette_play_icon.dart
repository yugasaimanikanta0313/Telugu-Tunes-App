import 'package:flutter/material.dart';

class CassettePlayIcon extends StatefulWidget {
  const CassettePlayIcon({super.key, required this.active});
  final bool active;

  @override
  State<CassettePlayIcon> createState() => _CassettePlayIconState();
}

class _CassettePlayIconState extends State<CassettePlayIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      _rotation.repeat();
    } else {
      _rotation.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CassettePlayIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 64,
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
                color: IconTheme.of(context).color ?? Colors.white, width: 2),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                    2,
                    (_) => RotationTransition(
                          turns: _rotation,
                          child: const Icon(Icons.settings_rounded, size: 21),
                        )),
              ),
              Icon(
                  widget.active
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 14),
            ],
          ),
        ),
      );
}

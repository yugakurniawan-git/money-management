import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnimatedNumber extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final int decimalPlaces;
  final Duration duration;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.prefix = 'Rp ',
    this.decimalPlaces = 0,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _animation = Tween<double>(begin: _oldValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pattern = widget.decimalPlaces > 0
        ? '#,##0.${'0' * widget.decimalPlaces}'
        : '#,##0';
    final formatter = NumberFormat(pattern, 'id_ID');
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = widget.decimalPlaces > 0
            ? _animation.value
            : _animation.value.roundToDouble();
        return Text(
          '${widget.prefix}${formatter.format(val)}',
          style: widget.style,
        );
      },
    );
  }
}

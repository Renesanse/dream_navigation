import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:animator/animator.dart';
import 'package:bolter_flutter/bolter_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class DreamNavigation extends StatefulWidget {
  final List<Widget> initialWidgets;

  const DreamNavigation({Key? key, required this.initialWidgets}) : super(key: key);

  @override
  State<DreamNavigation> createState() => DreamNavigationState();

  static DreamNavigationState of(BuildContext context) =>
      context.findAncestorStateOfType<DreamNavigationState>()!;
}

class DreamNavigationState extends State<DreamNavigation> {
  List<Widget> get _currentStack => widget.initialWidgets;

  late var _indexToDismiss = _currentStack.length - 1;
  final screenWidth = window.physicalSize.width / window.devicePixelRatio;

  var _initialDx = 0.0;
  var _positionDx = 0.0;

  var _animate = false;
  var _toLeft = true;

  Completer<void>? _processing;

  Future<void> add(Widget widget, [Completer<void>? processing]) {
    _processing = processing ?? Completer<void>();
    defaultBolter.runAndUpdate(action: () {
      _currentStack.add(widget);
      _indexToDismiss++;
      _positionDx = screenWidth;
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      defaultBolter.runAndUpdate(action: () {
        _animate = true;
        _toLeft = true;
      });
    });
    return _processing!.future;
  }

  Future<void> removeLast() {
    _processing = Completer();
    defaultBolter.runAndUpdate(action: () {});
    SchedulerBinding.instance.addPostFrameCallback((_) {
      defaultBolter.runAndUpdate(action: () {
        _toLeft = false;
        _animate = true;
      });
    });
    return _processing!.future;
  }

  Widget? _replacement;

  Future<void> replace(Widget widget) {
    _processing = Completer();
    _replacement = widget;
    removeLast();
    return _processing!.future;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStack.length > 1) {
          removeLast();
        }
        return true;
      },
      child: SyncBuilder(
        getter: () => _currentStack,
        builder: (ctx) {
          Widget? preLastWidget;
          if (_indexToDismiss > 0) {
            final preLastWidgetInStack = _currentStack[_indexToDismiss - 1];
            preLastWidget = _ScreenFoundation(
              key: preLastWidgetInStack.key ?? UniqueKey(),
              direction: true,
              currentOffset: () => _positionDx,
              child: preLastWidgetInStack,
            );
          }
          final lastInStack = _ScreenFoundation(
            currentOffset: () => _positionDx,
            direction: false,
            withCorners: false,
            child: _currentStack.last,
          );
          final lastWidget = _indexToDismiss > 0
              ? GestureDetector(
                  onHorizontalDragStart: (details) {
                    if (!_animate) {
                      _initialDx = details.globalPosition.dx;
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    if (!_animate) {
                      final currentX = details.globalPosition.dx;
                      if (currentX >= _initialDx) {
                        defaultBolter.runAndUpdate(action: () {
                          _positionDx = details.globalPosition.dx - _initialDx;
                        });
                      }
                    }
                  },
                  onHorizontalDragEnd: (details) {
                    if (!_animate && _positionDx != 0.0) {
                      defaultBolter.runAndUpdate(action: () {
                        _toLeft = _positionDx < screenWidth / 2;
                        return _animate = true;
                      });
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (preLastWidget != null) preLastWidget,
                      SyncBuilder(
                        getter: () => _animate,
                        builder: (_) {
                          return _animate
                              ? Animator<double>(
                                  triggerOnInit: true,
                                  resetAnimationOnRebuild: true,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.fastOutSlowIn,
                                  tween: _toLeft
                                      ? Tween(begin: _positionDx, end: 0.0)
                                      : Tween(begin: _positionDx, end: screenWidth),
                                  customListener: (status) {
                                    defaultBolter.runAndUpdate(
                                        action: () => _positionDx = status.value);
                                  },
                                  endAnimationListener: (_) {
                                    defaultBolter.runAndUpdate(action: () {
                                      _animate = false;
                                      _positionDx = 0.0;
                                      if (!_toLeft) {
                                        _indexToDismiss--;
                                        _currentStack.removeLast();
                                      }
                                    });
                                    if (_replacement != null) {
                                      add(_replacement!, _processing);
                                      _replacement = null;
                                    } else {
                                      _processing?.complete();
                                      _processing = null;
                                    }
                                  },
                                  builder: (_, status, __) {
                                    final position = status.value;
                                    return Positioned(
                                      top: 0,
                                      bottom: 0,
                                      left: position,
                                      right: -position,
                                      child: lastInStack,
                                    );
                                  },
                                )
                              : SyncBuilder<double>(
                                  getter: () => _positionDx,
                                  builder: (context) {
                                    return Positioned(
                                      top: 0,
                                      bottom: 0,
                                      left: _positionDx,
                                      right: -_positionDx,
                                      child: lastInStack,
                                    );
                                  },
                                );
                        },
                      ),
                    ],
                  ),
                )
              : lastInStack;
          return lastWidget;
        },
      ),
    );
  }
}

class _ScreenFoundation extends StatelessWidget {
  final double Function() currentOffset;
  final Widget child;
  final bool direction;
  final bool withCorners;

  const _ScreenFoundation({
    Key? key,
    required this.child,
    required this.currentOffset,
    required this.direction,
    this.withCorners = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _PostSpacer(
            direction: direction,
            offset: currentOffset,
          ),
          Expanded(
            child: Column(
              children: [
                _PostSpacer(
                  direction: direction,
                  offset: currentOffset,
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      withCorners
                          ? child
                          : ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                              child: child,
                            ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: SyncBuilder<double>(
                          getter: currentOffset,
                          builder: (ctx) {
                            final screenSize = window.physicalSize / window.devicePixelRatio;
                            final value = currentOffset();
                            final newValue = value / screenSize.width;
                            final calculated =
                                Curves.easeInQuint.transform(direction ? 1 - newValue : newValue);
                            return calculated == 0
                                ? const SizedBox.shrink()
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(Radius.circular(20)),
                                        color: Colors.black
                                            .withOpacity(Curves.decelerate.transform(calculated))),
                                  );
                          },
                        ),
                      ),
                      if (withCorners)
                        const Positioned(
                          bottom: 0,
                          left: 0,
                          child: _corner,
                        ),
                      if (withCorners)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Transform.rotate(
                            angle: -pi / 2,
                            child: _corner,
                          ),
                        ),
                      if (withCorners)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Transform.rotate(
                            angle: -pi,
                            child: _corner,
                          ),
                        ),
                      if (withCorners)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Transform.rotate(
                            angle: -1.5 * pi,
                            child: _corner,
                          ),
                        ),
                    ],
                  ),
                ),
                _PostSpacer(
                  direction: direction,
                  offset: currentOffset,
                ),
              ],
            ),
          ),
        ],
      );
}

class _PostSpacer extends StatelessWidget {
  final double Function() offset;
  final bool direction;

  const _PostSpacer({Key? key, required this.offset, required this.direction}) : super(key: key);

  @override
  Widget build(BuildContext context) => SyncBuilder<double>(
        getter: offset,
        builder: (context) {
          final screenSize = MediaQuery.of(context);
          final value = offset();
          final newValue = value / screenSize.size.width;
          final calculated = direction ? 1 - newValue : newValue;
          final calculatedPadding = 23 * calculated;
          if (calculatedPadding == 0) return const SizedBox.shrink();
          return SizedBox.square(dimension: calculatedPadding);
        },
      );
}

const _corner = SizedBox.square(
  dimension: 24,
  child: CustomPaint(
    foregroundPainter: _CornerPainter(Size.square(24)),
  ),
);

class _CornerPainter extends CustomPainter {
  final Size size;

  const _CornerPainter(this.size);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawPath(getTrianglePath(size.width, size.height), paint);
  }

  Path getTrianglePath(double x, double y) => Path()
    ..moveTo(0, 0)
    ..lineTo(-1, y)
    ..lineTo(x, y)
    ..quadraticBezierTo(0, size.width, 0, 0);

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => false;
}

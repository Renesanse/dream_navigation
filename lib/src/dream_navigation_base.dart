import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:animator/animator.dart';
import 'package:bolter_flutter/bolter_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class DreamNavigation extends StatefulWidget {
  final List<Widget> initialWidgets;
  final bool withFade;

  const DreamNavigation({
    Key? key,
    required this.initialWidgets,
    this.withFade = true,
  }) : super(key: key);

  @override
  State<DreamNavigation> createState() => DreamNavigationState();

  static DreamNavigationState of(BuildContext context) =>
      context.findAncestorStateOfType<DreamNavigationState>()!;
}

class DreamNavigationState extends State<DreamNavigation> {
  late final _bolter =
      context.findAncestorWidgetOfExactType<BolterProvider>()?.bolter ?? defaultBolter;

  late final _stackController = SyncBuilderController(_bolter,
      widget.initialWidgets.map((widget) => SizedBox(key: GlobalKey(), child: widget)).toList());

  late final _positionController = SyncBuilderController(_bolter, 0.0);
  late final _animateController = SyncBuilderController(_bolter, false);
  late var _toLeft = true;

  late var _indexToDismiss = widget.initialWidgets.length - 1;
  var _initialDx = 0.0;
  final _screenWidth = window.physicalSize.width / window.devicePixelRatio;

  Completer<void>? _processing;

  Future<void> add(Widget widget, [Completer<void>? processing]) {
    _processing = processing ?? Completer<void>();
    _stackController.update((value) => value..add(SizedBox(key: GlobalKey(), child: widget)));
    _indexToDismiss++;
    _positionController.update((value) => _screenWidth);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animateController.update((value) => true);
      _toLeft = true;
    });
    return _processing!.future;
  }

  Future<void> removeLast() {
    _processing = Completer();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animateController.update((value) => true);
      _toLeft = false;
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
        if (_stackController.value.length > 1) {
          removeLast();
        }
        return true;
      },
      child: SyncBuilder<List<Widget>>.controller(
        controller: _stackController,
        builder: (ctx, value) {
          Widget? preLastWidget;
          if (_indexToDismiss > 0) {
            final preLastWidgetInStack = value[_indexToDismiss - 1];
            preLastWidget = _ScreenFoundation(
              withFade: widget.withFade,
              direction: true,
              currentOffset: _positionController,
              child: preLastWidgetInStack,
            );
          }
          final lastInStack = _ScreenFoundation(
            withFade: widget.withFade,
            currentOffset: _positionController,
            direction: false,
            withCorners: false,
            child: value.last,
          );
          final animate = _animateController.value;

          final finalWidget = _indexToDismiss > 0
              ? GestureDetector(
            onHorizontalDragStart: (details) {
              if (!animate) {
                _initialDx = details.globalPosition.dx;
              }
            },
            onHorizontalDragUpdate: (details) {
              if (!animate) {
                final currentX = details.globalPosition.dx;
                if (currentX >= _initialDx) {
                  _positionController
                      .update((value) => details.globalPosition.dx - _initialDx);
                }
              }
            },
            onHorizontalDragEnd: (details) {
              if (!animate && _positionController.value != 0.0) {
                _toLeft = _positionController.value < _screenWidth / 2;
                _animateController.update((value) => true);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (preLastWidget != null) preLastWidget,
                SyncBuilder<bool>.controller(
                  controller: _animateController,
                  builder: (_, value) {
                    final positionDx = _positionController.value;
                    return value
                        ? Animator<double>(
                      triggerOnInit: true,
                      resetAnimationOnRebuild: true,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.fastOutSlowIn,
                      tween: _toLeft
                          ? Tween(begin: positionDx, end: 0.0)
                          : Tween(begin: positionDx, end: _screenWidth),
                      customListener: (status) {
                        _positionController.update((value) => status.value);
                      },
                      endAnimationListener: (_) {
                        _animateController.update((value) => false);
                        _positionController.update((value) => 0.0);
                        if (!_toLeft) {
                          _indexToDismiss--;
                          _stackController.update((value) => value..removeLast());
                        }
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
                        : SyncBuilder<double>.controller(
                      controller: _positionController,
                      builder: (context, value) {
                        return Positioned(
                          top: 0,
                          bottom: 0,
                          left: value,
                          right: -value,
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
          return finalWidget;
        },
      ),
    );
  }
}

class _ScreenFoundation extends StatelessWidget {
  final SyncBuilderController<double> currentOffset;
  final Widget child;
  final bool direction;
  final bool withCorners;
  final bool withFade;

  const _ScreenFoundation({
    Key? key,
    required this.child,
    required this.currentOffset,
    required this.direction,
    this.withCorners = true,
    this.withFade = true,
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
                  if (withFade)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: SyncBuilder<double>.controller(
                        controller: currentOffset,
                        builder: (ctx, value) {
                          final screenSize = window.physicalSize / window.devicePixelRatio;
                          final newValue = value / screenSize.width;
                          final calculated =
                          Curves.easeInQuint.transform(direction ? 1 - newValue : newValue);
                          return calculated == 0
                              ? const SizedBox.shrink()
                              : DecoratedBox(
                            decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(Radius.circular(20)),
                                color: Colors.black.withOpacity(
                                    Curves.decelerate.transform(calculated))),
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
  final SyncBuilderController<double> offset;
  final bool direction;

  const _PostSpacer({Key? key, required this.offset, required this.direction}) : super(key: key);

  @override
  Widget build(BuildContext context) => SyncBuilder<double>.controller(
    controller: offset,
    builder: (context, value) {
      final width = window.physicalSize.width / window.devicePixelRatio;
      final newValue = value / width;
      final calculated = direction ? 1 - newValue : newValue;
      final calculatedPadding = 24 * calculated;
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

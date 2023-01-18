import 'dart:math' as math;

import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import 'exceptions.dart';

class CircularNotchedAndCorneredRectangle extends NotchedShape {
  /// Creates a [CircularNotchedAndCorneredRectangle].
  ///
  /// The same object can be used to create multiple shapes.
  final Animation<double>? animation;
  final NotchSmoothness notchSmoothness;
  final GapLocation gapLocation;
  final double leftCornerRadius;
  final double rightCornerRadius;
  final double bottomLeftCornerRadius;
  final double bottomRightCornerRadius;
  final double marginLeft;
  final double marginRight;

  CircularNotchedAndCorneredRectangle({
    required this.notchSmoothness,
    required this.gapLocation,
    required this.leftCornerRadius,
    required this.rightCornerRadius,
    this.bottomLeftCornerRadius = 0,
    this.bottomRightCornerRadius = 0,
    this.marginLeft = 0,
    this.marginRight = 0,
    this.animation,
  });

  /// Creates a [Path] that describes a rectangle with a smooth circular notch.
  ///
  /// `host` is the bounding box for the returned shape. Conceptually this is
  /// the rectangle to which the notch will be applied.
  ///
  /// `guest` is the bounding box of a circle that the notch accommodates. All
  /// points in the circle bounded by `guest` will be outside of the returned
  /// path.
  ///
  /// The notch is curve that smoothly connects the host's top edge and
  /// the guest circle.
  @override
  Path getOuterPath(Rect host, Rect? guest) {
    double leftCornerRadius = this.leftCornerRadius * (animation?.value ?? 1);
    double rightCornerRadius = this.rightCornerRadius * (animation?.value ?? 1);
    var startX = host.left + marginLeft;
    var endX = host.right - marginRight;

    Path drawBeforeCenterPath(Path path) {
      return path
        ..moveTo(startX, host.bottom - bottomLeftCornerRadius)
        ..lineTo(startX, host.top + leftCornerRadius)
        ..arcToPoint(
          Offset(startX + leftCornerRadius, host.top),
          radius: Radius.circular(leftCornerRadius),
          clockwise: true,
        );
    }

    Path drawAfterCenterPath(Path path) {
      return path
        ..lineTo(endX - rightCornerRadius, host.top)
        ..arcToPoint(
          Offset(endX, host.top + rightCornerRadius),
          radius: Radius.circular(rightCornerRadius),
          clockwise: true,
        )
        ..lineTo(endX, host.bottom - bottomRightCornerRadius)
        ..arcToPoint(
          Offset(endX - bottomRightCornerRadius, host.bottom),
          radius: Radius.circular(bottomRightCornerRadius),
          clockwise: true,
        )
        ..lineTo(startX + bottomLeftCornerRadius, host.bottom)
        ..arcToPoint(
          Offset(startX, host.bottom - bottomLeftCornerRadius),
          radius: Radius.circular(bottomLeftCornerRadius),
          clockwise: true,
        );
    }

    if (guest == null || !host.overlaps(guest)) {
      if (this.rightCornerRadius > 0 || this.leftCornerRadius > 0) {
        var path = Path();
        drawBeforeCenterPath(path);
        drawAfterCenterPath(path);
        return path..close();
      }
      return Path()..addRect(host);
    }

    final guestCenterDx = guest.center.dx.toInt();
    final halfOfHostWidth = host.width ~/ 2;

    if (guestCenterDx == halfOfHostWidth) {
      if (gapLocation != GapLocation.center)
        throw GapLocationException(
            'Wrong gap location in $AnimatedBottomNavigationBar towards FloatingActionButtonLocation => '
            'consider use ${GapLocation.center} instead of $gapLocation or change FloatingActionButtonLocation');
    }

    if (guestCenterDx != halfOfHostWidth) {
      if (gapLocation != GapLocation.end)
        throw GapLocationException(
            'Wrong gap location in $AnimatedBottomNavigationBar towards FloatingActionButtonLocation => '
            'consider use ${GapLocation.end} instead of $gapLocation or change FloatingActionButtonLocation');
    }

    // The guest's shape is a circle bounded by the guest rectangle.
    // So the guest's radius is half the guest width.
    double notchRadius = guest.width / 2 * (animation?.value ?? 1);

    // We build a path for the notch from 3 segments:
    // Segment A - a Bezier curve from the host's top edge to segment B.
    // Segment B - an arc with radius notchRadius.
    // Segment C - a Bezier curve from segment B back to the host's top edge.
    //
    // A detailed explanation and the derivation of the formulas below is
    // available at: https://goo.gl/Ufzrqn

    final double s1 = notchSmoothness.s1;
    final double s2 = notchSmoothness.s2;

    double r = notchRadius;
    double a = -1.0 * r - s2;
    double b = host.top - guest.center.dy;

    double n2 = math.sqrt(b * b * r * r * (a * a + b * b - r * r));
    double p2xA = ((a * r * r) - n2) / (a * a + b * b);
    double p2xB = ((a * r * r) + n2) / (a * a + b * b);
    double p2yA = math.sqrt(r * r - p2xA * p2xA);
    double p2yB = math.sqrt(r * r - p2xB * p2xB);

    List<Offset> p = List.filled(6, Offset.zero, growable: true);

    // p0, p1, and p2 are the control points for segment A.
    p[0] = Offset(a - s1, b);
    p[1] = Offset(a, b);
    double cmp = b < 0 ? -1.0 : 1.0;
    p[2] = cmp * p2yA > cmp * p2yB ? Offset(p2xA, p2yA) : Offset(p2xB, p2yB);

    // p3, p4, and p5 are the control points for segment B, which is a mirror
    // of segment A around the y axis.
    p[3] = Offset(-1.0 * p[2].dx, p[2].dy);
    p[4] = Offset(-1.0 * p[1].dx, p[1].dy);
    p[5] = Offset(-1.0 * p[0].dx, p[0].dy);

    // translate all points back to the absolute coordinate system.
    for (int i = 0; i < p.length; i += 1) p[i] += guest.center;

    var path = Path();
    drawBeforeCenterPath(path);
    // draw chiseled section for docked fab
    path
      ..lineTo(p[0].dx, p[0].dy)
      ..quadraticBezierTo(p[1].dx, p[1].dy, p[2].dx, p[2].dy)
      ..arcToPoint(
        p[3],
        radius: Radius.circular(notchRadius),
        clockwise: false,
      )
      ..quadraticBezierTo(p[4].dx, p[4].dy, p[5].dx, p[5].dy);
    drawAfterCenterPath(path);
    return path..close();
  }
}

extension on NotchSmoothness? {
  static const curveS1 = {
    NotchSmoothness.sharpEdge: 0.0,
    NotchSmoothness.defaultEdge: 15.0,
    NotchSmoothness.softEdge: 20.0,
    NotchSmoothness.smoothEdge: 30.0,
    NotchSmoothness.verySmoothEdge: 40.0,
  };

  static const curveS2 = {
    NotchSmoothness.sharpEdge: 0.1,
    NotchSmoothness.defaultEdge: 1.0,
    NotchSmoothness.softEdge: 5.0,
    NotchSmoothness.smoothEdge: 15.0,
    NotchSmoothness.verySmoothEdge: 25.0,
  };

  double get s1 => curveS1[this] ?? 15.0;

  double get s2 => curveS2[this] ?? 1.0;
}

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

extension GapExtension on List<Widget> {
  List<Widget> addGap(double gap) {
    final List<Widget> result = [];
    final int lastIndex = length - 1;

    for (int i = 0; i < length; i++) {
      final Widget element = this[i];
      result.add(element);
      if (i != lastIndex) result.add(Gap(gap));
    }

    return result;
  }
}

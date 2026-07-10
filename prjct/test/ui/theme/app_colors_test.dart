import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/theme/app_colors.dart';

void main() {
  test('Adventure Map palette tokens have the spec-defined hex values', () {
    expect(AppColors.adventureBlue, const Color(0xFF72C9F8));
    expect(AppColors.adventurePurple, const Color(0xFF6C63D6));
    expect(AppColors.adventureGreen, const Color(0xFF5B9A1E));
  });
}

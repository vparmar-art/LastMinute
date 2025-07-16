import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  cardColor: AppColors.card,
  primaryColor: AppColors.accent,
  colorScheme: ColorScheme.dark(
    primary: AppColors.accent,
    secondary: AppColors.accent2,
    background: AppColors.background,
    surface: AppColors.card,
  ),
  textTheme: const TextTheme(
    titleLarge: AppTextStyles.heading,
    titleMedium: AppTextStyles.heading2,
    titleSmall: AppTextStyles.heading3,
    bodyLarge: AppTextStyles.body,
    bodyMedium: AppTextStyles.body1,
    bodySmall: AppTextStyles.bodySmall,
    labelLarge: AppTextStyles.button,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    elevation: 0,
    iconTheme: IconThemeData(color: AppColors.textPrimary),
    titleTextStyle: AppTextStyles.heading,
  ),
  buttonTheme: const ButtonThemeData(
    buttonColor: AppColors.accent,
    textTheme: ButtonTextTheme.primary,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: AppColors.card,
    border: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.accent),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    labelStyle: TextStyle(color: AppColors.textSecondary),
  ),
); 
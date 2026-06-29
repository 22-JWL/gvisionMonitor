import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF1565C0); // 파란 계열

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      );

  // 장비 상태 색상
  static Color statusColor(String mode) => switch (mode) {
        'Run' => const Color(0xFF43A047),    // green
        'SetUp' => const Color(0xFFFB8C00), // orange
        _ => const Color(0xFFE53935),        // red (OFFLINE)
      };

  static String statusLabel(String mode) => switch (mode) {
        'Run' => 'RUN',
        'SetUp' => 'SET UP',
        _ => 'OFFLINE',
      };

  // 이벤트 로그 타입 색상
  static Color logTypeColor(int logType) => switch (logType) {
        1 => const Color(0xFFE53935), // 시스템 — red
        2 => const Color(0xFFFB8C00), // 검사 — orange
        3 => const Color(0xFF9E9E9E), // DB — grey
        4 => const Color(0xFF42A5F5), // LOT — blue
        5 => const Color(0xFFAB47BC), // Recipe — purple
        _ => const Color(0xFF9E9E9E),
      };
}

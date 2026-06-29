import 'package:flutter/material.dart';

class RangeProvider extends ChangeNotifier {
  DateTime from;
  DateTime to;

  RangeProvider()
      : to = DateTime.now(),
        from = DateTime.now().subtract(const Duration(hours: 1));

  void setRange(DateTime f, DateTime t) {
    from = f;
    to = t;
    notifyListeners();
  }

  void setPreset(String type) {
    final now = DateTime.now();

    switch (type) {
      case '1H':
        setRange(now.subtract(const Duration(hours: 1)), now);
        break;
      case '6H':
        setRange(now.subtract(const Duration(hours: 6)), now);
        break;
      case 'TODAY':
        setRange(DateTime(now.year, now.month, now.day), now);
        break;
    }
  }
}
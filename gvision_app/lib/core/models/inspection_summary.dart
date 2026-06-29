class InspectionSummary {
  final int total;
  final int good;
  final int noDevice;
  final int reject;
  final int xout;

  const InspectionSummary({
    required this.total,
    required this.good,
    required this.noDevice,
    required this.reject,
    required this.xout,
  });

  factory InspectionSummary.empty() => const InspectionSummary(
        total: 0,
        good: 0,
        noDevice: 0,
        reject: 0,
        xout: 0,
      );

  double get yield_ =>
      total > 0 ? (good / (total - noDevice - xout)) * 100 : 0.0;
}

class TypeSummary {
  final String type; // 'MARK' | 'BGA' | '2DCODE'
  final int total;
  final int ng;

  const TypeSummary({
    required this.type,
    required this.total,
    required this.ng,
  });

  double get ngRate => total > 0 ? ng / total * 100 : 0.0;
}

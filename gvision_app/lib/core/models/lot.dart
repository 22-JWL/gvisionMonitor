class Lot {
  final int id;
  final String lotNo;
  final String? recipeName;
  final String startTime;
  final String? endTime;

  const Lot({
    required this.id,
    required this.lotNo,
    this.recipeName,
    required this.startTime,
    this.endTime,
  });

  factory Lot.fromJson(Map<String, dynamic> json) => Lot(
        id: json['Id'] as int? ?? json['id'] as int? ?? 0,
        lotNo: json['LotNumber'] as String? ?? json['LotNo'] as String? ?? json['lotNo'] as String? ?? '',
        recipeName: json['Package'] as String? ?? json['RecipeName'] as String? ?? json['recipeName'] as String?,
        startTime: json['StartTime'] as String? ?? json['startTime'] as String? ?? '',
        endTime: json['EndTime'] as String? ?? json['endTime'] as String?,
      );
}

class LotStats {
  final int total;
  final int good;
  final int noDevice;
  final int reject;
  final int xout;

  const LotStats({
    required this.total,
    required this.good,
    required this.noDevice,
    required this.reject,
    required this.xout,
  });

  factory LotStats.fromJson(Map<String, dynamic> json) => LotStats(
        total: json['total'] as int? ?? 0,
        good: json['good'] as int? ?? 0,
        noDevice: json['noDevice'] as int? ?? 0,
        reject: json['reject'] as int? ?? 0,
        xout: json['xout'] as int? ?? 0,
      );

  double get yield_ {
    final denominator = total - noDevice - xout;
    return denominator > 0 ? good / denominator * 100 : 0.0;
  }
}

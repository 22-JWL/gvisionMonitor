class DeviceStatus {
  final String runningMode; // 'Run' | 'SetUp' | 'OFFLINE'
  final String recipeName;
  final String lotNo;

  const DeviceStatus({
    required this.runningMode,
    required this.recipeName,
    required this.lotNo,
  });

  factory DeviceStatus.offline() => const DeviceStatus(
        runningMode: 'OFFLINE',
        recipeName: '(연결 없음)',
        lotNo: '-',
      );

  factory DeviceStatus.fromJson(Map<String, dynamic> json) => DeviceStatus(
        runningMode: json['runningMode'] as String? ?? 'OFFLINE',
        recipeName: json['recipeName'] as String? ?? '',
        lotNo: json['lotNo'] as String? ?? '-',
      );

  bool get isRunning => runningMode == 'Run';
  bool get isSetup => runningMode == 'SetUp';
  bool get isOffline => runningMode == 'OFFLINE';
}

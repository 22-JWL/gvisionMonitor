import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/api/inspections_api.dart';
import '../../core/ws/ws_client.dart';
import '../../services/notification_service.dart';
import '../../services/notification_settings.dart';

enum RangeType { hour1, hour6, today }

enum ShotResultFilter {
  all,
  failOnly,
  yieldDrop,
}

class InspectionProvider extends ChangeNotifier {
  final WsClient _ws;

  List<dynamic> _series = [];
  List<Map<String, dynamic>> yieldSeries = [];
  List<Map<String, dynamic>> durationSeries = [];
  List<Map<String, dynamic>> heatmapData = [];
  int? _lastHeatmapLotId;
  bool loading = true;
  String? errorMessage;

  List<dynamic> get series => List.unmodifiable(_series);

  int? get _latestLotId {
    for (int i = _series.length - 1; i >= 0; i--) {
      final id = _series[i]['LotId'] as int?;
      if (id != null) return id;
    }
    return null;
  }

  RangeType _rangeType = RangeType.today;
  RangeType get rangeType => _rangeType;

  double dropThreshold = 5.0;

  void setDropThreshold(double value) {
    dropThreshold = value;
    notifyListeners();
  }

  double abnormalYieldThreshold = 90.0;

  void setAbnormalYieldThreshold(double value) {
    abnormalYieldThreshold = value;
    notifyListeners();
  }

  // 수율 임계값 감지용 — 첫 로드는 알림 없이 skip
  double _prevYieldRate = -1;

  // 오늘 집계
  int total = 0, good = 0, noDevice = 0, reject = 0, xout = 0;
  // 타입별 (1=MARK, 3=BGA, 5=2DCODE)
  int markTotal = 0, markNg = 0;
  int bgaTotal = 0, bgaNg = 0;
  int codeTotal = 0, codeNg = 0;

  StreamSubscription<WsMessage>? _sub;
  Timer? _pollTimer;

  InspectionProvider(this._ws) {
    _init();
  }

  Future<void> _init() async {
    await _fetch();

    // 검사 결과(logType=2) 새 이벤트 수신 시 즉시 갱신
    _sub = _ws.stream.listen((msg) {
      if (msg.type == WsMessageType.newEvent ||
          msg.type == WsMessageType.alert) {
        final logType = msg.data['LogType'] as int?;
        if (logType == 2) _fetch(); // InspectionLogs
      }
    });

    // 30초마다 폴링 (WebSocket이 놓친 변경 보완)
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final now = DateTime.now();

      DateTime from;

      switch (_rangeType) {
        case RangeType.hour1:
          from = now.subtract(const Duration(hours: 1));
          break;
        case RangeType.hour6:
          from = now.subtract(const Duration(hours: 6));
          break;
        case RangeType.today:
        default:
          from = DateTime(now.year, now.month, now.day);
          break;
      }

      final results = await Future.wait([
        InspectionsApi.fetchSeries(from: from, to: now),
        InspectionsApi.fetchYieldSeries(from: from, to: now),
        InspectionsApi.fetchDurationSeries(from: from, to: now),
      ]);

      _series = (results[0] as List).cast<dynamic>();
      yieldSeries = (results[1] as List).cast<Map<String, dynamic>>();
      durationSeries = (results[2] as List).cast<Map<String, dynamic>>();

      final lotId = _latestLotId;
      if (lotId != null && lotId != _lastHeatmapLotId) {
        _lastHeatmapLotId = lotId;
        heatmapData = await InspectionsApi.fetchHeatmap(lotId);
      }

      _aggregate();
      errorMessage = null;
    } catch (e) {
      errorMessage = '서버 연결 실패 — 데이터를 불러오지 못했습니다.';
      debugPrint('[InspectionProvider] fetch 에러: $e');
    }

    loading = false;
    _checkYieldAlert();
    notifyListeners();
  }

  void _checkYieldAlert() {
    final current = yieldRate;
    final threshold = NotificationSettings.yieldThreshold;

    // 첫 로드 시에는 알림 없이 기준값만 저장
    if (_prevYieldRate < 0) {
      _prevYieldRate = current;
      return;
    }

    // 임계값 이상 → 미만으로 떨어질 때만 알림 (중복 방지)
    if (NotificationSettings.yieldAlertEnabled &&
        _prevYieldRate >= threshold &&
        current < threshold) {
      NotificationService.showYieldAlert(
        yieldRate: current,
        threshold: threshold,
      );
    }

    _prevYieldRate = current;
  }



  void _aggregate() {
    total = _series.length;
    good = noDevice = reject = xout = 0;
    markTotal = markNg = bgaTotal = bgaNg = codeTotal = codeNg = 0;

    for (final r in _series) {
      final item = r['Item'] as String? ?? '';
      final type = r['InspectionType'] as int? ?? 0;

      if (item == 'PASS') {
        good++;
      } else if (item.contains('NoDevice')) {
        noDevice++;
      } else if (item.contains('XOut')) {
        xout++;
      } else {
        reject++;
      }

      switch (type) {
        case 1:
          markTotal++;
          if (item != 'PASS') markNg++;
        case 3:
          bgaTotal++;
          if (item != 'PASS') bgaNg++;
        case 5:
          codeTotal++;
          if (item != 'PASS') codeNg++;
      }
    }
  }

  double get yieldRate {
    final denom = total - noDevice - xout;
    return denom > 0 ? good / denom * 100 : 0.0;
  }

  void setRange(RangeType type) {
    _rangeType = type;
    loading = true;
    notifyListeners();
    _fetch();
  }

  Future<void> refresh() => _fetch();

  @override
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  //shot filter
  ShotResultFilter shotFilter = ShotResultFilter.all;
  String selectedInspectionType = 'ALL'; // ALL, MARK, BGA, 2D
  double yieldThreshold = 90.0;

  void setShotFilter(ShotResultFilter filter) {
    shotFilter = filter;
    notifyListeners();
  }

  void setInspectionType(String type) {
    selectedInspectionType = type;
    notifyListeners();
  }

  void setYieldThreshold(double value) {
    yieldThreshold = value;
    notifyListeners();
  }

  DateTime? _parseShotTime(dynamic shot) {
    final raw = shot['StartTIme']?.toString() ??
        shot['StartTime']?.toString() ??
        shot['startTime']?.toString() ??
        shot['EndTime']?.toString() ??
        shot['CreatedAt']?.toString() ??
        shot['createdAt']?.toString() ??
        shot['created_at']?.toString() ??
        shot['Time']?.toString() ??
        shot['time']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  // yieldSeries에서 dropThreshold 이상 급락한 구간의 시간 반환
  DateTime? _findDropTime() {
    if (yieldSeries.length < 2) return null;
    int? dropIndex;
    double biggestDrop = 0;
    for (int i = 1; i < yieldSeries.length; i++) {
      final prev = (yieldSeries[i - 1]['yield'] as num).toDouble();
      final curr = (yieldSeries[i]['yield'] as num).toDouble();
      final diff = curr - prev;
      if (diff < biggestDrop) {
        biggestDrop = diff;
        dropIndex = i;
      }
    }
    if (dropIndex == null || biggestDrop > -dropThreshold) return null;
    final raw = yieldSeries[dropIndex]['minute']?.toString() ?? '';
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  List<dynamic> get filteredShots {
    final dropTime = shotFilter == ShotResultFilter.yieldDrop
        ? _findDropTime()
        : null;

    return _series.where((shot) {
      final item = shot['Item'] as String? ?? '';
      final type = shot['InspectionType'] as int? ?? 0;
      final isFail = item != 'PASS';

      final typeName = switch (type) {
        1 => 'MARK',
        3 => 'BGA',
        5 => '2D',
        _ => 'UNKNOWN',
      };

      final matchType = selectedInspectionType == 'ALL' ||
          selectedInspectionType == typeName;

      bool matchResult;
      switch (shotFilter) {
        case ShotResultFilter.all:
          matchResult = true;
        case ShotResultFilter.failOnly:
          matchResult = isFail;
        case ShotResultFilter.yieldDrop:
          if (!isFail) {
            matchResult = false;
          } else if (dropTime == null) {
            // 급락 구간 미감지 시 전체 FAIL 표시
            matchResult = true;
          } else {
            final t = _parseShotTime(shot);
            matchResult = t != null &&
                t.isAfter(dropTime.subtract(const Duration(minutes: 5))) &&
                t.isBefore(dropTime.add(const Duration(minutes: 5)));
          }
      }

      return matchType && matchResult;
    }).toList();
  }
}

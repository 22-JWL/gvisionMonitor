import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/api/lots_api.dart';
import '../../core/models/lot.dart';
import '../../core/ws/ws_client.dart';
import '../../services/lot_memo_service.dart';
import '../../shared/widgets/ws_indicator.dart';

class LotsScreen extends StatefulWidget {
  const LotsScreen({super.key});

  @override
  State<LotsScreen> createState() => _LotsScreenState();
}

class _LotsScreenState extends State<LotsScreen> {
  List<Lot> _lots = [];
  bool _loading = true;
  String? _error;
  bool _compareMode = false;

  // 단일 보기
  Lot? _selectedLot;
  LotStats? _selectedStats;
  bool _statsLoading = false;

  // 비교 모드 — 삽입 순서 보존 (Dart Map은 기본적으로 순서 유지)
  final Map<int, (Lot, LotStats?)> _compareMap = {};
  static const _maxCompare = 2;

  // 메모 — lotId → memo
  final Map<int, LotMemo> _memos = {};
  Set<int> _memoIds = {};

  static const _palette = [
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFEF5350),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lots = await LotsApi.fetchLots(limit: 30);
      final memoIds = await LotMemoService.loadExistingIds(
          lots.map((l) => l.id).toList());
      setState(() {
        _lots = lots;
        _memoIds = memoIds;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Lot 목록을 불러오지 못했습니다. 서버 연결을 확인하세요.';
      });
    }
  }

  Future<void> _selectLot(Lot lot) async {
    setState(() {
      _selectedLot = lot;
      _selectedStats = null;
      _statsLoading = true;
    });
    try {
      final results = await Future.wait([
        LotsApi.fetchStats(lot.id),
        LotMemoService.load(lot.id),
      ]);
      if (!mounted) return;
      setState(() {
        _selectedStats = results[0] as LotStats;
        final memo = results[1] as LotMemo?;
        if (memo != null) {
          _memos[lot.id] = memo;
        } else {
          _memos.remove(lot.id);
        }
        _statsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }

  Future<void> _toggleCompare(Lot lot) async {
    if (_compareMap.containsKey(lot.id)) {
      setState(() => _compareMap.remove(lot.id));
      return;
    }
    if (_compareMap.length >= _maxCompare) return;

    setState(() => _compareMap[lot.id] = (lot, null));
    try {
      final stats = await LotsApi.fetchStats(lot.id);
      if (!mounted) return;
      setState(() => _compareMap[lot.id] = (lot, stats));
    } catch (_) {}
  }

  void _toggleMode() {
    setState(() {
      _compareMode = !_compareMode;
      _compareMap.clear();
    });
  }

  List<int> get _compareKeys => _compareMap.keys.toList();

  Color _colorFor(int lotId) {
    final idx = _compareKeys.indexOf(lotId);
    return idx >= 0 ? _palette[idx % _palette.length] : Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lot 이력'),
        actions: [
          const WsIndicator(),
          TextButton.icon(
            icon: Icon(
              _compareMode ? Icons.close : Icons.compare_arrows,
              size: 18,
            ),
            label: Text(_compareMode ? '비교 종료' : '비교 모드'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: _toggleMode,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '데이터 조회 중...',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (_error != null)
                  Material(
                    color: Colors.red.shade900,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: const Text(
                              '재시도',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: _lots.isEmpty
                      ? const Center(
                          child: Text('Lot 없음', style: TextStyle(color: Colors.white38)),
                        )
                      : Row(
                          children: [
                            Expanded(flex: 5, child: _lotListPanel()),
                            Container(width: 1, color: Colors.white12),
                            Expanded(
                              flex: 5,
                              child: _compareMode ? _comparePanel() : _lotDetailPanel(),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  // ── Lot 목록 패널 ─────────────────────────────────────────────────────────

  Widget _lotListPanel() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: Color(0xFF90CAF9)),
                const SizedBox(width: 8),
                const Text(
                  'Lot 목록',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                if (_compareMode) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_compareMap.length} / $_maxCompare',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _compareMode
                    ? '비교할 Lot을 최대 $_maxCompare개 선택하세요.'
                    : '최근 생산 Lot을 선택하면 우측에서 품질 요약을 확인할 수 있습니다.',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _lots.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _compareMode
                  ? _compareTile(_lots[i])
                  : _singleTile(_lots[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _singleTile(Lot lot) {
    final selected = _selectedLot?.id == lot.id;
    return InkWell(
      onTap: () => _selectLot(lot),
      child: Container(
        color: selected
            ? const Color(0xFF1976D2).withOpacity(0.14)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? const Color(0xFF90CAF9) : Colors.white38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lot.lotNo,
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lot.recipeName ?? '-',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            if (_memoIds.contains(lot.id))
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.edit_note,
                    size: 14, color: Color(0xFFFFCA28)),
              ),
            Text(
              _formatDate(lot.startTime),
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compareTile(Lot lot) {
    final isSelected = _compareMap.containsKey(lot.id);
    final isDisabled = !isSelected && _compareMap.length >= _maxCompare;
    final color = isSelected ? _colorFor(lot.id) : null;

    return InkWell(
      onTap: isDisabled ? null : () => _toggleCompare(lot),
      child: Container(
        color: isSelected ? color!.withOpacity(0.10) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color! : Colors.white38,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lot.lotNo,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                      color: isDisabled ? Colors.white30 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lot.recipeName ?? '-',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Text(
              _formatDate(lot.startTime),
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  // ── 단일 상세 패널 ────────────────────────────────────────────────────────

  Widget _lotDetailPanel() {
    final lot = _selectedLot;

    if (lot == null) {
      return const Card(
        margin: EdgeInsets.all(12),
        child: Center(
          child: Text(
            'Lot을 선택하면 상세 품질 정보가 표시됩니다.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    if (_statsLoading) {
      return const Card(
        margin: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final stats = _selectedStats;
    if (stats == null) {
      return const Card(
        margin: EdgeInsets.all(12),
        child: Center(
          child: Text(
            'Lot 통계를 불러오지 못했습니다.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final yieldColor = stats.yield_ >= 99
        ? const Color(0xFF43A047)
        : stats.yield_ >= 95
            ? Colors.orange
            : const Color(0xFFE53935);

    final status = stats.yield_ >= 99
        ? '정상'
        : stats.yield_ >= 95
            ? '주의'
            : '위험';

    return Card(
      margin: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check,
                    size: 18, color: Color(0xFF90CAF9)),
                const SizedBox(width: 8),
                const Text(
                  'Lot 품질 요약',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${lot.lotNo} / ${lot.recipeName ?? '-'}',
              style:
                  const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _bigMetric('상태', status, yieldColor, Icons.fact_check)),
              const SizedBox(width: 12),
              Expanded(child: _bigMetric('YIELD', '${stats.yield_.toStringAsFixed(1)}%', yieldColor, Icons.percent)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _bigMetric('TOTAL', '${stats.total}', Colors.white70, Icons.inventory_2)),
              const SizedBox(width: 12),
              Expanded(child: _bigMetric('GOOD', '${stats.good}', const Color(0xFF43A047), Icons.check_circle)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _bigMetric('REJECT', '${stats.reject}', const Color(0xFFE53935), Icons.cancel)),
              const SizedBox(width: 12),
              Expanded(child: _bigMetric('NO DEVICE', '${stats.noDevice}', Colors.grey, Icons.remove_circle)),
            ]),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: yieldColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: yieldColor.withOpacity(0.3)),
              ),
              child: Text(
                stats.yield_ >= 99
                    ? '이 Lot은 안정적인 검사 품질을 보입니다.'
                    : stats.yield_ >= 95
                        ? '이 Lot은 수율 주의 구간입니다. REJECT와 NO DEVICE 비중을 확인하세요.'
                        : '이 Lot은 수율 위험 구간입니다. 해당 Lot의 검사 조건과 Recipe 변경 이력을 함께 확인하세요.',
                style: TextStyle(fontSize: 12, height: 1.4, color: yieldColor),
              ),
            ),
            const SizedBox(height: 16),
            _MemoCard(
              lot: lot,
              initialMemo: _memos[lot.id],
              onSaved: (memo) {
                setState(() {
                  _memos[lot.id] = memo;
                  _memoIds.add(lot.id);
                });
              },
              onDeleted: () {
                setState(() {
                  _memos.remove(lot.id);
                  _memoIds.remove(lot.id);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 비교 패널 ─────────────────────────────────────────────────────────────

  Widget _comparePanel() {
    if (_compareMap.isEmpty) {
      return const Card(
        margin: EdgeInsets.all(12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.compare_arrows, size: 40, color: Colors.white24),
              SizedBox(height: 12),
              Text(
                '비교할 Lot을 왼쪽에서 선택하세요',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    final entries = _compareMap.entries.toList();
    final isAnyLoading = entries.any((e) => e.value.$2 == null);

    return Card(
      margin: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                const Icon(Icons.compare_arrows,
                    size: 18, color: Color(0xFF90CAF9)),
                const SizedBox(width: 8),
                const Text(
                  'Lot 비교',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '선택한 Lot들의 수율과 검사 결과를 나란히 비교합니다.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
            const SizedBox(height: 12),

            // 로딩 표시
            if (isAnyLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            // 범례
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: entries.asMap().entries.map((e) {
                final color = _palette[e.key % _palette.length];
                final lot = e.value.value.$1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      lot.lotNo,
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                  ],
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 수율 막대 차트
            _yieldBarChart(entries),

            const SizedBox(height: 12),

            // 상세 비교 테이블
            const Text(
              '상세 비교',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 8),

            _comparisonTable(entries),

            const Divider(height: 24),

            // 비교 결과 요약
            _summaryCard(entries),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── 비교 결과 요약 ────────────────────────────────────────────────────────

  List<(String, Color)> _generateInsights(
      List<MapEntry<int, (Lot, LotStats?)>> entries) {
    final loaded = entries.where((e) => e.value.$2 != null).toList();
    if (loaded.isEmpty) return [];

    final insights = <(String, Color)>[];

    // 수율 최고/최저 찾기
    var minEntry = loaded.first;
    var maxEntry = loaded.first;
    for (final e in loaded) {
      if (e.value.$2!.yield_ < minEntry.value.$2!.yield_) minEntry = e;
      if (e.value.$2!.yield_ > maxEntry.value.$2!.yield_) maxEntry = e;
    }

    final minYield = minEntry.value.$2!.yield_;
    final maxYield = maxEntry.value.$2!.yield_;
    final spread = maxYield - minYield;

    // 수율 편차 인사이트
    if (loaded.length >= 2 && spread >= 0.5) {
      insights.add((
        '${minEntry.value.$1.lotNo} 수율이 가장 낮음 (-${spread.toStringAsFixed(1)}%p)',
      Colors.white,
      ));
    }

    // Reject 집중 인사이트
    final maxRejectEntry = loaded.reduce(
        (a, b) => a.value.$2!.reject > b.value.$2!.reject ? a : b);
    final maxReject = maxRejectEntry.value.$2!.reject;

    if (maxReject > 0) {
      final others =
          loaded.where((e) => e.key != maxRejectEntry.key).toList();
      final avgOther = others.isEmpty
          ? 0.0
          : others.fold(0, (sum, e) => sum + e.value.$2!.reject) /
              others.length;

      if (avgOther == 0 || maxReject > avgOther * 1.5) {
        insights.add((
          '${maxRejectEntry.value.$1.lotNo}에서 Reject 집중 (${maxReject}건)',
        Colors.white,
        ));
      }
    }

    // Recipe 변경 감지
    final recipes =
        loaded.map((e) => e.value.$1.recipeName ?? '').toSet();
    if (recipes.length > 1) {
      insights.add((
        'Recipe 변경 이력 있음 — 수율 변화 원인 확인 필요',
      Colors.white,
      ));
    }

    // 최고 수율 Lot
    if (loaded.length >= 2 && spread >= 0.5) {
      insights.add((
        '${maxEntry.value.$1.lotNo}이 수율 최고 (${maxYield.toStringAsFixed(1)}%)',
      Colors.white,
      ));
    }

    // 모든 Lot이 안정적인 경우
    if (insights.isEmpty) {
      insights.add((
        '선택한 Lot 간 수율 편차가 적어 공정이 안정적입니다.',
      Colors.white,
      ));
    }

    return insights;
  }

  Widget _summaryCard(List<MapEntry<int, (Lot, LotStats?)>> entries) {
    final loaded = entries.where((e) => e.value.$2 != null).toList();

    // 아직 하나도 로드 안 됐으면 숨김
    if (loaded.isEmpty) return const SizedBox.shrink();

    final insights = _generateInsights(entries);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF42A5F5).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_outlined,
                  size: 15, color: Color(0xFF90CAF9)),
              SizedBox(width: 6),
              Text(
                '비교 결과 요약',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF90CAF9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: insight.$2,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      insight.$1,
                      style: TextStyle(
                        fontSize: 12,
                        color: insight.$2,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yieldBarChart(
      List<MapEntry<int, (Lot, LotStats?)>> entries) {
    final loaded =
        entries.where((e) => e.value.$2 != null).toList();

    if (loaded.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('데이터 로딩 중...', style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          maxY: 100,
          minY: 0,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= loaded.length) {
                    return const SizedBox();
                  }
                  final lotNo = loaded[idx].value.$1.lotNo;
                  final label = lotNo.length > 8
                      ? '${lotNo.substring(0, 8)}..'
                      : lotNo;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.white54),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: loaded.asMap().entries.map((e) {
            final barIdx = e.key;
            final lotId = e.value.key;
            final stats = e.value.value.$2!;
            final colorIdx = _compareKeys.indexOf(lotId);
            final color = _palette[colorIdx % _palette.length];

            return BarChartGroupData(
              x: barIdx,
              barRods: [
                BarChartRodData(
                  toY: stats.yield_,
                  color: color,
                  width: 56,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: color.withOpacity(0.08),
                  ),
                ),
              ],
            );
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final lot = loaded[groupIndex].value.$1;
                return BarTooltipItem(
                  '${lot.lotNo}\n${rod.toY.toStringAsFixed(1)}%',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _comparisonTable(
      List<MapEntry<int, (Lot, LotStats?)>> entries) {
    final rows = [
      ('YIELD', Icons.percent),
      ('TOTAL', Icons.inventory_2),
      ('GOOD', Icons.check_circle),
      ('REJECT', Icons.cancel),
      ('NO DEVICE', Icons.remove_circle),
      ('X-OUT', Icons.block),
    ];

    return Table(
      border: TableBorder.all(color: Colors.white12),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const FixedColumnWidth(82),
        for (int i = 0; i < entries.length; i++)
          i + 1: const FlexColumnWidth(),
      },
      children: [
        // 헤더 행
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text('항목',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.bold)),
            ),
            ...entries.asMap().entries.map((e) {
              final color = _palette[e.key % _palette.length];
              final lot = e.value.value.$1;
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 8),
                child: Text(
                  lot.lotNo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),

        // 데이터 행
        ...rows.map((row) {
          final label = row.$1;
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54)),
              ),
              ...entries.map((e) {
                final stats = e.value.$2;
                if (stats == null) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final value = _statValue(label, stats);
                final color = _statColor(label, stats);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 10),
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  String _statValue(String label, LotStats s) => switch (label) {
        'YIELD' => '${s.yield_.toStringAsFixed(1)}%',
        'TOTAL' => '${s.total}',
        'GOOD' => '${s.good}',
        'REJECT' => '${s.reject}',
        'NO DEVICE' => '${s.noDevice}',
        'X-OUT' => '${s.xout}',
        _ => '-',
      };

  Color _statColor(String label, LotStats s) => switch (label) {
        'YIELD' => s.yield_ >= 99
            ? const Color(0xFF43A047)
            : s.yield_ >= 95
                ? Colors.orange
                : const Color(0xFFE53935),
        'GOOD' => const Color(0xFF43A047),
        'REJECT' =>
          s.reject > 0 ? const Color(0xFFE53935) : Colors.white70,
        'NO DEVICE' => Colors.grey,
        'X-OUT' => s.xout > 0 ? Colors.orange : Colors.white70,
        _ => Colors.white70,
      };

  Widget _bigMetric(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white54)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 교대 기록 카드 ────────────────────────────────────────────────────────────

class _MemoCard extends StatefulWidget {
  final Lot lot;
  final LotMemo? initialMemo;
  final void Function(LotMemo) onSaved;
  final VoidCallback onDeleted;

  const _MemoCard({
    required this.lot,
    required this.initialMemo,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<_MemoCard> createState() => _MemoCardState();
}

class _MemoCardState extends State<_MemoCard> {
  late final TextEditingController _commentCtrl;
  late DateTime _managedAt;
  bool _saving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final memo = widget.initialMemo;
    _commentCtrl = TextEditingController(text: memo?.comment ?? '');
    _managedAt = memo?.managedAt ?? DateTime.now();
    _isEditing = memo == null; // 메모 없으면 바로 편집 모드
  }

  @override
  void didUpdateWidget(_MemoCard old) {
    super.didUpdateWidget(old);
    if (old.lot.id != widget.lot.id) {
      final memo = widget.initialMemo;
      _commentCtrl.text = memo?.comment ?? '';
      _managedAt = memo?.managedAt ?? DateTime.now();
      _isEditing = memo == null;
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _managedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_managedAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _managedAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) return;

    setState(() => _saving = true);
    final memo = LotMemo(
      comment: comment,
      managedAt: _managedAt,
      savedAt: DateTime.now(),
    );
    await LotMemoService.save(widget.lot.id, memo);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _isEditing = false;
    });
    widget.onSaved(memo);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('교대 기록이 저장됐습니다.')),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 Lot의 교대 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await LotMemoService.delete(widget.lot.id);
    if (!mounted) return;
    setState(() {
      _commentCtrl.clear();
      _managedAt = DateTime.now();
      _isEditing = true;
    });
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final hasMemo = widget.initialMemo != null && !_isEditing;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasMemo
              ? const Color(0xFFFFCA28).withOpacity(0.4)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 16,
                  color: hasMemo
                      ? const Color(0xFFFFCA28)
                      : Colors.white38,
                ),
                const SizedBox(width: 6),
                const Text(
                  '교대 기록',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                if (!_isEditing) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    color: Colors.white38,
                    tooltip: '수정',
                    onPressed: () => setState(() => _isEditing = true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: Colors.white38,
                    tooltip: '삭제',
                    onPressed: _delete,
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 12, indent: 14, endIndent: 14),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _isEditing ? _editView() : _readView(),
          ),
        ],
      ),
    );
  }

  Widget _readView() {
    final memo = widget.initialMemo!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 교대 시간
        Row(
          children: [
            const Icon(Icons.access_time, size: 13, color: Colors.white38),
            const SizedBox(width: 5),
            Text(
              '교대 시간: ${_fmt(memo.managedAt)}',
              style:
                  const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            const Spacer(),
            Text(
              '저장: ${_fmt(memo.savedAt)}',
              style:
                  const TextStyle(fontSize: 10, color: Colors.white30),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 코멘트
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            memo.comment,
            style: const TextStyle(
                fontSize: 13, color: Colors.white, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _editView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 교대 시간 선택
        InkWell(
          onTap: _pickTime,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    size: 15, color: Colors.white54),
                const SizedBox(width: 8),
                Text(
                  '교대 시간: ${_fmt(_managedAt)}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
                const Spacer(),
                const Icon(Icons.edit_calendar_outlined,
                    size: 14, color: Colors.white38),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 코멘트 입력
        TextField(
          controller: _commentCtrl,
          maxLines: 4,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: '교대 시 현장 상황, 특이사항, 인수인계 내용을 기록하세요.',
            hintStyle: TextStyle(fontSize: 12, color: Colors.white30),
            border: OutlineInputBorder(),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),

        // 버튼 행
        Row(
          children: [
            if (widget.initialMemo != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _commentCtrl.text =
                        widget.initialMemo!.comment;
                    _managedAt = widget.initialMemo!.managedAt;
                    _isEditing = false;
                  }),
                  child: const Text('취소'),
                ),
              ),
            if (widget.initialMemo != null) const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, size: 16),
                label: const Text('저장'),
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

String _formatDate(String raw) {
  if (raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
    return '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return raw.length > 10 ? raw.substring(0, 10) : raw;
  }
}

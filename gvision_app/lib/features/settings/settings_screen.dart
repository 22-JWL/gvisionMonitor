import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../services/notification_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;

  // 알림 설정 로컬 상태 (저장 전 버퍼)
  bool _sys       = NotificationSettings.sysEnabled;
  bool _insp      = NotificationSettings.inspEnabled;
  bool _lot       = NotificationSettings.lotEnabled;
  bool _recipe    = NotificationSettings.recipeEnabled;
  bool _yieldOn   = NotificationSettings.yieldAlertEnabled;
  double _thresh  = NotificationSettings.yieldThreshold;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: ApiClient.host);
    _portCtrl = TextEditingController(text: '${ApiClient.port}');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveServer() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 4000;
    await ApiClient.saveSettings(host, port);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 주소가 저장됐습니다. 앱을 재시작하면 적용됩니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _serverCard(),
                  const SizedBox(height: 16),
                  _notifTypeCard(),
                  const SizedBox(height: 16),
                  _yieldAlertCard(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: _infoCard(),
            ),
          ],
        ),
      ),
    );
  }

  // ── 서버 설정 ─────────────────────────────────────────────────────────────

  Widget _serverCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.dns, size: 22),
              SizedBox(width: 8),
              Text('서버 연결 설정',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ]),
            const SizedBox(height: 8),
            const Text(
              'GVision 서버의 IP와 포트를 설정합니다. 현장 태블릿이 장비 PC와 같은 네트워크에 연결되어 있어야 합니다.',
              style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _hostCtrl,
              decoration: const InputDecoration(
                labelText: '서버 IP 주소',
                hintText: '예: 192.168.0.100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _portCtrl,
              decoration: const InputDecoration(
                labelText: '포트',
                hintText: '4000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('저장'),
                onPressed: _saveServer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 이벤트 유형별 알림 설정 ───────────────────────────────────────────────

  Widget _notifTypeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.notifications_active, size: 22),
              SizedBox(width: 8),
              Text('이벤트 알림 설정',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ]),
            const SizedBox(height: 6),
            const Text(
              '수신할 이벤트 유형을 선택하세요. 끄면 해당 이벤트가 발생해도 알림이 오지 않습니다.',
              style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 12),
            _notifToggle(
              label: '시스템 이벤트',
              sub: '장비 오류, 서버 상태 변경',
              color: const Color(0xFF42A5F5),
              value: _sys,
              isCritical: true,
              onChanged: (v) {
                setState(() => _sys = v);
                NotificationSettings.setSys(v);
              },
            ),
            _notifToggle(
              label: '검사 이벤트',
              sub: '검사 결과 수신 시 (빈도 높음 — 주의)',
              color: const Color(0xFF66BB6A),
              value: _insp,
              onChanged: (v) {
                setState(() => _insp = v);
                NotificationSettings.setInsp(v);
              },
            ),
            _notifToggle(
              label: 'LOT 이벤트',
              sub: 'LOT 시작, 종료, 변경',
              color: const Color(0xFFFFCA28),
              value: _lot,
              onChanged: (v) {
                setState(() => _lot = v);
                NotificationSettings.setLot(v);
              },
            ),
            _notifToggle(
              label: 'Recipe 이벤트',
              sub: 'Recipe 변경 시',
              color: const Color(0xFFAB47BC),
              value: _recipe,
              onChanged: (v) {
                setState(() => _recipe = v);
                NotificationSettings.setRecipe(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifToggle({
    required String label,
    required String sub,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isCritical = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  if (isCritical) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('긴급',
                          style: TextStyle(
                              fontSize: 9, color: Color(0xFFEF5350))),
                    ),
                  ],
                ]),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  // ── 수율 임계값 알림 ──────────────────────────────────────────────────────

  Widget _yieldAlertCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.trending_down, size: 22, color: Color(0xFFEF5350)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('수율 경고 알림',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
              ),
              Switch(
                value: _yieldOn,
                onChanged: (v) {
                  setState(() => _yieldOn = v);
                  NotificationSettings.setYieldAlert(v);
                },
                activeColor: const Color(0xFFEF5350),
              ),
            ]),
            const SizedBox(height: 6),
            const Text(
              '수율이 기준치 미만으로 떨어지면 긴급 알림을 발송합니다.',
              style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: _yieldOn ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('경고 임계값',
                          style: TextStyle(
                              fontSize: 13, color: Colors.white70)),
                      const Spacer(),
                      Text(
                        '${_thresh.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF5350),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _thresh,
                    min: 80,
                    max: 99,
                    divisions: 19,
                    activeColor: const Color(0xFFEF5350),
                    inactiveColor: Colors.white12,
                    label: '${_thresh.toStringAsFixed(0)}%',
                    onChanged: _yieldOn
                        ? (v) {
                            setState(() => _thresh = v);
                            NotificationSettings.setYieldThreshold(v);
                          }
                        : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('80%',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white38)),
                      Text('99%',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFEF5350).withOpacity(0.25)),
                    ),
                    child: Text(
                      '현재 수율이 ${_thresh.toStringAsFixed(0)}% 미만으로 떨어지면 긴급 채널로 즉시 알림을 발송합니다.',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF5350),
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 앱 정보 ───────────────────────────────────────────────────────────────

  Widget _infoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.info_outline, size: 22),
              SizedBox(width: 8),
              Text('앱 정보',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17)),
            ]),
            const SizedBox(height: 18),
            _infoRow('앱 이름', 'GVision Monitor'),
            _infoRow('버전', 'v1.0.0'),
            _infoRow('용도', '현장 장비 상태 모니터링 및 검사 알림 분석'),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '서버 주소 변경 후에는 앱을 재시작해야 완전히 반영됩니다.\n알림 설정은 즉시 적용됩니다.',
                style: TextStyle(
                    fontSize: 12, color: Colors.white70, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Colors.white54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

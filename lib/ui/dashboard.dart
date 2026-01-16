import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../providers/devices_provider.dart';
import '../providers/selected_device_provider.dart';

/// LocationX Manager (Windows)
/// - 전문 설정 프로그램 느낌의 "Settings" 레이아웃
/// - 좌측: Discover/Device 목록
/// - 우측: 선택 장비 상세 + (MQTT / Actions / Details) 탭
class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> with TickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  // MQTT
  final TextEditingController _mqttHostCtrl = TextEditingController();
  final TextEditingController _mqttPortCtrl = TextEditingController(text: '1883');

  // Actions
  final TextEditingController _rebootDelayCtrl = TextEditingController(text: '2');

  String? _status;
  String? _lastSelectedIp;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() {
      final s = _searchCtrl.text.trim();
      if (s == _search) return;
      setState(() => _search = s);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _mqttHostCtrl.dispose();
    _mqttPortCtrl.dispose();
    _rebootDelayCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // UI helpers
  // -------------------------
  Widget _micaCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.78),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  Widget _statusChip(Device? d) {
    final cs = Theme.of(context).colorScheme;
    final host = (d?.mqttHost ?? '').trim();
    final port = d?.mqttPort;
    final ok = host.isNotEmpty && port != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? cs.primaryContainer.withOpacity(0.65) : cs.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Text(
        ok ? 'MQTT(UDP): $host:$port' : 'MQTT(UDP): 확인안됨',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }

  Widget _ledIndicator(Device d) {
    if (d.ledState == LedState.blink) {
      if (!d.blinkPhase) return const SizedBox(width: 18, height: 18);
      return const Icon(Icons.circle, color: Colors.orange, size: 16);
    }
    if (d.ledState == LedState.on) {
      return const Icon(Icons.circle, color: Colors.green, size: 16);
    }
    return const Icon(Icons.circle_outlined, color: Colors.grey, size: 16);
  }

  List<Device> _filtered(List<Device> devices) {
    final q = _search.toLowerCase();
    if (q.isEmpty) return devices;
    return devices.where((d) {
      final h = d.hostname.toLowerCase();
      final ip = d.ip.toLowerCase();
      final mac = (d.mac ?? '').toLowerCase();
      final mqtt = '${d.mqttHost ?? ''}:${d.mqttPort ?? ''}'.toLowerCase();
      return h.contains(q) || ip.contains(q) || mac.contains(q) || mqtt.contains(q);
    }).toList();
  }

  void _syncEditorsFromSelected(Device? d) {
    if (d == null) return;
    if (_lastSelectedIp == d.ip) return;
    _lastSelectedIp = d.ip;

    // ✅ 선택 장비가 바뀔 때마다 에디터를 "항상" 동기화
    // 이전 버전은 mqttHost가 비어있으면 텍스트필드를 비우지 않아
    // 다른 장비의 값(=예전 IP)이 남아 혼동되는 문제가 생길 수 있음.
    final h = (d.mqttHost ?? '').trim();
    _mqttHostCtrl.text = h; // 비어있으면 비우기

    final p = d.mqttPort;
    if (p != null && p > 0 && p <= 65535) {
      _mqttPortCtrl.text = p.toString();
    } else {
      _mqttPortCtrl.text = '1883';
    }
    _status = null;
  }

  bool _hasPendingMqtt(Device d) {
    final curHost = (d.mqttHost ?? '').trim();
    final curPort = d.mqttPort ?? 1883;

    final editHost = _mqttHostCtrl.text.trim();
    final editPort = int.tryParse(_mqttPortCtrl.text.trim()) ?? 1883;

    return (editHost != curHost) || (editPort != curPort);
  }

  // -------------------------
  // Actions
  // -------------------------
  Future<void> _discover() async {
    final ctrl = ref.read(devicesControllerProvider.notifier);
    await ctrl.discoverUdp();
  }

  Future<void> _sendMqtt(Device d) async {
    final host = _mqttHostCtrl.text.trim();
    final port = int.tryParse(_mqttPortCtrl.text.trim());
    if (host.isEmpty) {
      setState(() => _status = 'MQTT 서버(Host)를 입력하세요.');
      return;
    }
    if (port == null || port <= 0 || port > 65535) {
      setState(() => _status = 'MQTT Port는 1~65535 범위로 입력하세요.');
      return;
    }

    final ctrl = ref.read(devicesControllerProvider.notifier);
    final resp = await ctrl.setMqttUdp(ip: d.ip, brokerHost: host, brokerPort: port);

    final ok = (resp['ok'] == true);
    final rh = (resp['broker_host'] ?? resp['host'] ?? '').toString().trim();
    final rp = resp['broker_port'] ?? resp['port'];
    final rpInt = (rp is num) ? rp.toInt() : int.tryParse(rp?.toString() ?? '');

    setState(() {
      _status = ok
          ? '저장 완료 (UDP): ${rh.isEmpty ? host : rh}:${rpInt ?? port}\n적용은 “Restart AOA Service” 또는 Reboot 후 반영됩니다.'
          : '실패: ${(resp['error'] ?? 'unknown').toString()}';
    });
  }

  Future<void> _identify(Device d) async {
    final ctrl = ref.read(devicesControllerProvider.notifier);
    await ctrl.identify(d.ip);
    if (!mounted) return;
    setState(() => _status = 'Identify 실행: ${d.hostname} (${d.ip})');
  }

  Future<void> _restartAoaService(Device d) async {
    // MQTT 탭에서 입력만 바꾸고 저장을 안 한 채로 재시작을 누르면
    // "예전 IP"로 다시 뜨는 것으로 보일 수 있어서, 먼저 안내/선택 제공.
    if (_hasPendingMqtt(d)) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('저장되지 않은 MQTT 변경사항'),
          content: const Text('MQTT 탭에서 입력한 값이 아직 장비에 저장되지 않았습니다.\n\n저장 후 서비스 재시작을 진행할까요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('취소')),
            OutlinedButton(onPressed: () => Navigator.pop(context, 'restart_only'), child: const Text('재시작만')),
            FilledButton(onPressed: () => Navigator.pop(context, 'save_and_restart'), child: const Text('저장 후 재시작')),
          ],
        ),
      );

      if (choice == 'cancel' || choice == null) return;

      if (choice == 'save_and_restart') {
        await _sendMqtt(d);
        // 저장 실패면 여기서 멈춤
        if (!mounted) return;
        if ((_status ?? '').startsWith('실패')) return;
      }
      // restart_only or save_and_restart -> 계속 진행
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AOA 서비스 재시작'),
        content: Text('${d.hostname} (${d.ip})\n\nsudo systemctl restart aoa-antenna.service\n\n진행할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('재시작')),
        ],
      ),
    );
    if (ok != true) return;

    final ctrl = ref.read(devicesControllerProvider.notifier);
    final resp = await ctrl.restartAoaServiceUdp(ip: d.ip);

    final success = (resp['ok'] == true);
    final rc = resp['rc']?.toString() ?? '';
    final err = (resp['err'] ?? resp['error'] ?? '').toString();

    setState(() {
      _status = success ? 'AOA 서비스 재시작 완료 (rc=$rc)' : 'AOA 서비스 재시작 실패: $err (rc=$rc)';
    });
  }

  Future<void> _reboot(Device d) async {
    final delay = int.tryParse(_rebootDelayCtrl.text.trim()) ?? 2;
    final applied = delay.clamp(0, 30);

    if (_hasPendingMqtt(d)) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('저장되지 않은 MQTT 변경사항'),
          content: const Text('MQTT 탭에서 입력한 값이 아직 장비에 저장되지 않았습니다.\n\n저장 후 재부팅을 진행할까요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('취소')),
            OutlinedButton(onPressed: () => Navigator.pop(context, 'reboot_only'), child: const Text('재부팅만')),
            FilledButton(onPressed: () => Navigator.pop(context, 'save_and_reboot'), child: const Text('저장 후 재부팅')),
          ],
        ),
      );

      if (choice == 'cancel' || choice == null) return;

      if (choice == 'save_and_reboot') {
        await _sendMqtt(d);
        if (!mounted) return;
        if ((_status ?? '').startsWith('실패')) return;
      }
      // reboot_only or save_and_reboot -> 계속 진행
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('장비 재부팅'),
        content: Text('${d.hostname} (${d.ip})\n\n재부팅을 실행합니다.\n지연: ${applied}s\n\n진행할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('재부팅')),
        ],
      ),
    );
    if (ok != true) return;

    final ctrl = ref.read(devicesControllerProvider.notifier);
    final resp = await ctrl.rebootUdp(ip: d.ip, delaySec: applied, reason: 'ui');
    final success = (resp['ok'] == true);

    setState(() {
      _status = success ? '재부팅 예약됨 (UDP): ${d.hostname} - ${applied}s' : '재부팅 실패: ${(resp['error'] ?? 'unknown')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(devicesControllerProvider);
    final selected = ref.watch(selectedDeviceProvider);
    _syncEditorsFromSelected(selected);

    final cs = Theme.of(context).colorScheme;
    final devices = _filtered(st.devices);

    return Scaffold(
      body: Stack(
        children: [
          // “바탕화면” 느낌 배경
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primaryContainer.withOpacity(0.55),
                    cs.surface,
                    cs.secondaryContainer.withOpacity(0.25),
                  ],
                ),
              ),
              child: const _NoiseOverlay(),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    children: [
                      const Icon(Icons.settings_suggest, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'LocationX Manager',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      if (selected != null) _statusChip(selected),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: (st.discovering || st.busy) ? null : _discover,
                        icon: const Icon(Icons.radar),
                        label: Text(st.discovering ? 'Discovering…' : 'Discover (UDP)'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: st.devices.isEmpty
                            ? null
                            : () {
                                ref.read(devicesControllerProvider.notifier).clearDevices();
                                ref.read(selectedDeviceIdProvider.notifier).state = null;
                                setState(() => _status = null);
                              },
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Main
                  Expanded(
                    child: Row(
                      children: [
                        // Left: Devices
                        SizedBox(
                          width: 520,
                          child: _micaCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Devices', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 10),
                                    Text(
                                      '(${devices.length}/${st.devices.length})',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _searchCtrl,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _search.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Clear',
                                            onPressed: () => _searchCtrl.clear(),
                                            icon: const Icon(Icons.close),
                                          ),
                                    hintText: 'Search by hostname / IP / MAC / MQTT…',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (st.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(st.error!, style: TextStyle(color: cs.error)),
                                  ),
                                Expanded(
                                  child: devices.isEmpty
                                      ? Center(
                                          child: Text(
                                            'Discover(UDP)를 누르면 같은 LAN의 LocationX 장비가 응답합니다.\n\n'
                                            '• 항목을 클릭하면 우측에서 설정\n'
                                            '• 길게 누르면 Identify(LED 점멸)',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: devices.length,
                                          separatorBuilder: (_, __) => const Divider(height: 10),
                                          itemBuilder: (context, i) {
                                            final d = devices[i];
                                            final selectedTile = selected?.ip == d.ip;
                                            final macLabel = (d.mac == null || d.mac!.isEmpty) ? 'N/A' : d.mac!;
                                            final mqttLabel = ((d.mqttHost ?? '').trim().isEmpty || d.mqttPort == null)
                                                ? '확인안됨'
                                                : '${d.mqttHost}:${d.mqttPort}';

                                            return InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: () => ref.read(selectedDeviceIdProvider.notifier).state = d.ip,
                                              onLongPress: st.busy ? null : () => _identify(d),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: selectedTile ? cs.primaryContainer.withOpacity(0.35) : cs.surfaceContainerHighest.withOpacity(0.35),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: cs.outlineVariant.withOpacity(0.28)),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: _ledIndicator(d),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  d.hostname,
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Text(
                                                                d.fw,
                                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            'IP: ${d.ip}   •   MAC: $macLabel',
                                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            'MQTT(UDP): $mqttLabel',
                                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Right: Settings
                        Expanded(
                          child: _micaCard(
                            padding: const EdgeInsets.all(0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Device Settings',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const Spacer(),
                                      if (selected != null)
                                        Text(
                                          '${selected.hostname}  (${selected.ip})',
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                                        ),
                                    ],
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: TabBar(
                                    controller: _tabs,
                                    tabs: const [
                                      Tab(text: 'MQTT'),
                                      Tab(text: 'Actions'),
                                      Tab(text: 'Details'),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),

                                Expanded(
                                  child: TabBarView(
                                    controller: _tabs,
                                    children: [
                                      _MqttTab(
                                        selected: selected,
                                        hostCtrl: _mqttHostCtrl,
                                        portCtrl: _mqttPortCtrl,
                                        busy: st.busy,
                                        onSend: (d) => _sendMqtt(d),
                                      ),
                                      _ActionsTab(
                                        selected: selected,
                                        busy: st.busy,
                                        delayCtrl: _rebootDelayCtrl,
                                        onIdentify: (d) => _identify(d),
                                        onRestartService: (d) => _restartAoaService(d),
                                        onReboot: (d) => _reboot(d),
                                      ),
                                      _DetailsTab(selected: selected),
                                    ],
                                  ),
                                ),

                                if (_status != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                                    child: _StatusBanner(text: _status!),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}

class _MqttTab extends StatelessWidget {
  final Device? selected;
  final TextEditingController hostCtrl;
  final TextEditingController portCtrl;
  final bool busy;
  final Future<void> Function(Device device) onSend;

  const _MqttTab({
    required this.selected,
    required this.hostCtrl,
    required this.portCtrl,
    required this.busy,
    required this.onSend,
  });

  String _current(Device d) {
    final h = (d.mqttHost ?? '').trim();
    final p = d.mqttPort;
    if (h.isEmpty || p == null) return '확인안됨';
    return '$h:$p';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = selected;

    if (d == null) {
      return Center(
        child: Text(
          '좌측에서 장비를 선택하세요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('MQTT (UDP)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          '현재 적용된 서버: ${_current(d)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: hostCtrl,
                decoration: const InputDecoration(
                  labelText: 'Broker Host',
                  hintText: '예) aoa-server-1.local 또는 192.168.1.10',
                  prefixIcon: Icon(Icons.dns),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: portCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            FilledButton.icon(
              onPressed: busy ? null : () => onSend(d),
              icon: const Icon(Icons.save),
              label: Text(busy ? 'Saving…' : 'Save MQTT (UDP)'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () {
                // 편의: 포트만 기본값으로
                if (portCtrl.text.trim().isEmpty) portCtrl.text = '1883';
              },
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Default Port'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '• 저장만으로는 실행 중인 로케이터가 즉시 바뀌지 않습니다.\n'
          '  적용하려면 “Actions” 탭에서 Restart AOA Service 또는 Reboot를 실행하세요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ActionsTab extends StatelessWidget {
  final Device? selected;
  final bool busy;
  final TextEditingController delayCtrl;
  final Future<void> Function(Device device) onIdentify;
  final Future<void> Function(Device device) onRestartService;
  final Future<void> Function(Device device) onReboot;

  const _ActionsTab({
    required this.selected,
    required this.busy,
    required this.delayCtrl,
    required this.onIdentify,
    required this.onRestartService,
    required this.onReboot,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = selected;

    if (d == null) {
      return Center(
        child: Text(
          '좌측에서 장비를 선택하세요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _ActionCard(
          title: 'Identify (LED Blink)',
          subtitle: '장비를 찾기 쉽게 LED 점멸을 실행합니다.',
          icon: Icons.wifi_tethering,
          primaryLabel: 'Run',
          primaryEnabled: !busy,
          onPrimary: () => onIdentify(d),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Restart AOA Service',
          subtitle: 'sudo systemctl restart aoa-antenna.service',
          icon: Icons.refresh,
          primaryLabel: 'Restart',
          primaryEnabled: !busy,
          onPrimary: () => onRestartService(d),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Reboot Device',
          subtitle: '전체 재부팅 (현장 운영 시 신중히).',
          icon: Icons.restart_alt,
          primaryLabel: 'Reboot',
          primaryEnabled: !busy,
          onPrimary: () => onReboot(d),
          trailing: SizedBox(
            width: 180,
            child: TextField(
              controller: delayCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Delay (sec)',
                hintText: '0~30',
                prefixIcon: Icon(Icons.timer),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final Device? selected;
  const _DetailsTab({required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = selected;
    if (d == null) {
      return Center(
        child: Text(
          '좌측에서 장비를 선택하세요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    final mqtt = ((d.mqttHost ?? '').trim().isEmpty || d.mqttPort == null) ? '확인안됨' : '${d.mqttHost}:${d.mqttPort}';
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _Kv('Hostname', d.hostname),
        _Kv('IP', d.ip),
        _Kv('MAC', (d.mac == null || d.mac!.isEmpty) ? 'N/A' : d.mac!),
        _Kv('FW', d.fw),
        _Kv('MQTT(UDP)', mqtt),
        const SizedBox(height: 16),
        Text(
          '• Discover(UDP) 응답에 포함되는 MQTT 정보가 없으면 “확인안됨”으로 표시됩니다.\n'
          '• MQTT 저장 후 적용하려면 Actions 탭에서 재시작/재부팅을 실행하세요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Kv extends StatelessWidget {
  final String k;
  final String v;
  const _Kv(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback onPrimary;
  final Widget? trailing;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.onPrimary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.28)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: primaryEnabled ? onPrimary : null,
                      child: Text(primaryLabel),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      Expanded(child: trailing!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String text;
  const _StatusBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOk = text.contains('완료') || text.contains('저장 완료') || text.contains('예약됨');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isOk ? cs.primaryContainer : cs.errorContainer).withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isOk ? Icons.check_circle : Icons.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 아주 약한 "노이즈" 도트로 배경에 깊이감을 줌 (이미지/에셋 없이)
class _NoiseOverlay extends StatelessWidget {
  const _NoiseOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NoisePainter(Theme.of(context).colorScheme.onSurface.withOpacity(0.03)),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final Color color;
  _NoisePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // 규칙적인 도트(가벼운 텍스처). 성능 위해 간격 크게.
    const step = 18.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = (y / step).floor() % 2 == 0 ? 0 : step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => oldDelegate.color != color;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/selected_device_provider.dart';
import '../services/config_web_api.dart';

class ConfigPanel extends ConsumerStatefulWidget {
  const ConfigPanel({super.key});

  @override
  ConsumerState<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends ConsumerState<ConfigPanel> {
  final api = const ConfigWebApi();

  final mqttCtrl = TextEditingController();
  final locatorCtrl = TextEditingController();
  final positioningCtrl = TextEditingController();

  bool loading = false;
  bool dirty = false;
  String? error;

  @override
  void initState() {
    super.initState();
    mqttCtrl.addListener(_markDirty);
    locatorCtrl.addListener(_markDirty);
    positioningCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (!dirty) setState(() => dirty = true);
  }

  @override
  void dispose() {
    mqttCtrl.dispose();
    locatorCtrl.dispose();
    positioningCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final dev = ref.read(selectedDeviceProvider);
    if (dev == null) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await api.load(dev.ip);
      mqttCtrl.text = data['mqtt']!;
      locatorCtrl.text = data['locator']!;
      positioningCtrl.text = data['positioning']!;
      setState(() => dirty = false);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> save() async {
    final dev = ref.read(selectedDeviceProvider);
    if (dev == null) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await api.save(
        ip: dev.ip,
        mqtt: mqttCtrl.text,
        locator: locatorCtrl.text,
        positioning: positioningCtrl.text,
      );
      setState(() => dirty = false);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> apply() async {
    final dev = ref.read(selectedDeviceProvider);
    if (dev == null) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await api.apply(dev.ip);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Widget editor(String title, TextEditingController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          height: 220,
          child: TextField(
            controller: c,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dev = ref.watch(selectedDeviceProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dev == null
                  ? '선택된 장비 없음'
                  : '${dev.hostname} (${dev.ip}) / ${dev.mac ?? "N/A"}',
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: loading ? null : load,
                  child: const Text('Load (GET /)'),
                ),
                FilledButton(
                  onPressed: (!dirty || loading) ? null : save,
                  child: const Text('Save Staging'),
                ),
                FilledButton(
                  onPressed: loading ? null : apply,
                  child: const Text('Apply'),
                ),
              ],
            ),

            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    editor('mqtt_server_setting.txt', mqttCtrl),
                    editor('locator_config.json (Single)', locatorCtrl),
                    editor('positioning_config.json (Multiple)', positioningCtrl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

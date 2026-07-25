import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import '../../adapters/coach/gemma_benchmark.dart';

/// One-tap on-device latency measurement.
///
/// Exists so the number that decides the demo — how long Gemma takes to write
/// a follow-up question on the *actual* phone — can be obtained without
/// writing any code on the morning of the event.
///
/// The model is **sideloaded**, not downloaded: pull the file on a machine
/// that is logged in to Hugging Face, then
///
/// ```
/// adb push gemma3-1b-it-int4.task \
///   /sdcard/Android/data/pe.oratoria.oratoria_kids/files/
/// ```
///
/// That keeps the Hugging Face token out of the app entirely and means nothing
/// has to be downloaded at the venue.
class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final _filename = TextEditingController(text: 'gemma3-1b-it-int4.task');

  ModelType _modelType = ModelType.gemmaIt;
  PreferredBackend _backend = PreferredBackend.gpu;

  bool _running = false;
  String? _error;
  String? _modelDir;
  List<BenchmarkRun> _runs = const [];

  @override
  void initState() {
    super.initState();
    _resolveModelDir();
  }

  @override
  void dispose() {
    _filename.dispose();
    super.dispose();
  }

  Future<void> _resolveModelDir() async {
    final dir = await getExternalStorageDirectory();
    if (mounted) setState(() => _modelDir = dir?.path);
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
      _runs = const [];
    });

    try {
      final path = '$_modelDir/${_filename.text.trim()}';
      if (!File(path).existsSync()) {
        throw StateError(
          'No existe el archivo:\n$path\n\n'
          'Empújalo con:\nadb push ${_filename.text.trim()} $_modelDir/',
        );
      }

      // Point the plugin at the sideloaded file. Deprecated in 0.16.5 in
      // favour of the 1.x builder API, which does not exist on this Dart SDK.
      // ignore: deprecated_member_use
      await FlutterGemmaPlugin.instance.modelManager.setModelPath(path);

      final runs = await GemmaBenchmark(
        modelType: _modelType,
        backend: _backend,
      ).run();

      if (mounted) setState(() => _runs = runs);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  /// Everything needed to paste the result into the team chat.
  String get _summary {
    final backend = _backend.name.toUpperCase();
    final lines = _runs.map((r) => '  $r').join('\n');
    return 'OratorIA · Gemma benchmark\n'
        'modelo: ${_filename.text.trim()} (${_modelType.name})\n'
        'backend: $backend\n$lines';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Benchmark de Gemma')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Mide cuánto tarda Gemma en este equipo. Corre esto en el '
              'teléfono del demo — el emulador usa la GPU de la PC y da un '
              'número que ningún celular reproduce.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _filename,
              decoration: const InputDecoration(
                labelText: 'Archivo del modelo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _modelDir == null
                  ? 'Resolviendo carpeta…'
                  : 'adb push <modelo> $_modelDir/',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<ModelType>(
              initialValue: _modelType,
              decoration: const InputDecoration(
                labelText: 'Tipo de modelo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: ModelType.gemmaIt,
                  child: Text('gemmaIt — Gemma 3 1B / 270M'),
                ),
                DropdownMenuItem(
                  value: ModelType.gemma4,
                  child: Text('gemma4 — Gemma 4 E2B / E4B'),
                ),
              ],
              onChanged: (v) => setState(() => _modelType = v ?? _modelType),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PreferredBackend>(
              initialValue: _backend,
              decoration: const InputDecoration(
                labelText: 'Backend',
                border: OutlineInputBorder(),
                helperText: 'GPU vs CPU cambia la latencia un orden de magnitud',
              ),
              items: const [
                DropdownMenuItem(
                  value: PreferredBackend.gpu,
                  child: Text('GPU (OpenCL)'),
                ),
                DropdownMenuItem(
                  value: PreferredBackend.cpu,
                  child: Text('CPU — para comparar'),
                ),
              ],
              onChanged: (v) => setState(() => _backend = v ?? _backend),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Midiendo…' : 'Medir'),
            ),
            if (_running) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text(
                'La primera generación incluye la carga del modelo y es la '
                'más lenta. Puede tardar minutos con un modelo grande.',
                style: TextStyle(fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(_error!),
              ),
            ],
            if (_runs.isNotEmpty) ...[
              const SizedBox(height: 24),
              for (final run in _runs) _RunCard(run: run),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _summary));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resultado copiado')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar resultado'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  final BenchmarkRun run;

  const _RunCard({required this.run});

  @override
  Widget build(BuildContext context) {
    final seconds = run.elapsed.inMilliseconds / 1000;
    final verdict = _verdict(seconds);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    run.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${seconds.toStringAsFixed(1)} s',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${run.responseTokens} tokens · '
              '${run.tokensPerSecond.toStringAsFixed(1)} tok/s',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              verdict,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: seconds <= 6 ? Colors.green.shade800 : Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              run.response.trim(),
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  String _verdict(double seconds) {
    if (seconds < 2) return 'Va directo, sin animación de espera.';
    if (seconds <= 6) return 'Vox "piensa" y tapa la espera. Sirve.';
    if (seconds <= 12) return 'Riesgoso: acorta el prompt o baja de modelo.';
    return 'No presentes esto: cambia de modelo o de equipo.';
  }
}

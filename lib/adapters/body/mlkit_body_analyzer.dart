import 'dart:async';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:oratoria_core/oratoria_core.dart';

/// Reads the child's body language from the front camera with ML Kit Face
/// Detection — the app's second modality (voice + body). Fully on-device: the
/// model is BUNDLED (`com.google.mlkit:face-detection`), so it works offline
/// on a freshly-installed phone with no download.
///
/// Frugal by design for the A12 sharing ~490 MB with Gemma resident:
/// low resolution, FAST mode, no contours/landmarks, and ~4 fps with a
/// busy-drop throttle so frames never queue. Body language is slow — one frame
/// in seven is plenty, and it keeps CPU and heat down.
///
/// Golden rule: nothing here is on the audio critical path, and no corrective
/// text ever shows live. It aggregates silently; the verdict reaches the final
/// report only if there was enough data ([BodyMetrics.hasData]).
class MlKitBodyLanguageAnalyzer {
  static const _minFrameGap = Duration(milliseconds: 240); // ~4 fps

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true, // smilingProbability
    ),
  );

  CameraController? _controller;
  bool _busy = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  int _frames = 0;
  int _eyes = 0;
  int _smiles = 0;

  /// The preview controller once [start] succeeds — null when unavailable.
  CameraController? get controller => _controller;
  bool get isAvailable => _controller?.value.isInitialized ?? false;

  /// Initialise the front camera and begin sampling. Returns false on any
  /// failure (no camera, denied permission, init error) so the session simply
  /// continues audio-only.
  Future<bool> start() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _rotation =
          InputImageRotationValue.fromRawValue(front.sensorOrientation) ??
              InputImageRotation.rotation0deg;

      final controller = CameraController(
        front,
        ResolutionPreset.low, // ~240p — enough for a face, cheap on the A12
        enableAudio: false, // the recorder owns audio
        imageFormatGroup: ImageFormatGroup.nv21, // single-plane, ML Kit-ready
      );
      await controller.initialize();
      await controller.startImageStream(_onFrame);
      _controller = controller;
      return true;
    } catch (e) {
      debugPrint('Body analyzer unavailable: $e');
      await _dispose();
      return false;
    }
  }

  void _onFrame(CameraImage image) {
    // Throttle + drop-if-busy: never let frames queue behind Gemma/UI work.
    if (_busy ||
        DateTime.now().difference(_lastRun) < _minFrameGap) {
      return;
    }
    _busy = true;
    _lastRun = DateTime.now();
    _process(image).whenComplete(() => _busy = false);
  }

  Future<void> _process(CameraImage image) async {
    final input = _toInputImage(image);
    if (input == null) return;
    try {
      final faces = await _detector.processImage(input);
      if (faces.isEmpty) return;
      final f = faces.first;
      _frames++;
      final y = f.headEulerAngleY ?? 90;
      final z = f.headEulerAngleZ ?? 90;
      // Head pointed at the camera ≈ "looked at the audience" (a proxy, not
      // real gaze — the report wording must never overstate it).
      if (y.abs() < 20 && z.abs() < 15) _eyes++;
      if ((f.smilingProbability ?? 0) > 0.5) _smiles++;
    } catch (_) {
      // A single bad frame must never break the session.
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first; // nv21 is a single plane
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Stop sampling and return the aggregate. [BodyMetrics.none] when no face
  /// was ever seen — we never invent a "you didn't look" for a shy child in
  /// poor light.
  Future<BodyMetrics> stop() async {
    final frames = _frames;
    final eyes = _eyes;
    final smiles = _smiles;
    await _dispose();
    if (frames == 0) return BodyMetrics.none;
    return BodyMetrics(
      eyeContactRatio: eyes / frames,
      smileRatio: smiles / frames,
      uprightRatio: 0, // no pose in the MVP
      framesAnalyzed: frames,
    );
  }

  Future<void> _dispose() async {
    final c = _controller;
    _controller = null;
    try {
      if (c != null) {
        if (c.value.isStreamingImages) await c.stopImageStream();
        await c.dispose();
      }
    } catch (_) {}
    try {
      await _detector.close();
    } catch (_) {}
  }
}

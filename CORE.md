Pose Detection Core - Projektzusammenfassung

Überblick

Ziel: Generischer, domain-agnostischer Core für Echtzeit-Pose-Erkennung mit ML
Kit. Perfekte Basis für zukünftige Fitness/Physio Use Cases.

Status: Core komplett, Inspection Dashboard funktionsfähig, bereit für Domain
Layer.

---

Architektur

lib/ ├── core/ # Domain-agnostisch │ ├── interfaces/ # Abstractions für
Testbarkeit │ │ ├── camera_service_interface.dart │ │ ├──
pose_detector_interface.dart │ │ ├── pose_buffer_interface.dart │ │ └──
frame_processor_interface.dart │ ├── config/ │ │ ├── pose_detection_config.dart
# Magic Numbers, Thresholds │ │ └── landmark_schema.dart # 33 ML Kit Landmarks +
Skeleton │ ├── data_structures/ │ │ ├── ring_buffer.dart # O(1) generischer
Buffer │ │ └── pose_buffer.dart │ ├── services/ │ │ ├── camera_service.dart #
Kamera-Lifecycle, Front/Back Switch │ │ ├── pose_detection_service.dart # ML Kit
Wrapper │ │ ├── frame_processor.dart # Frame → Pose Pipeline │ │ ├──
session_manager.dart # Session Lifecycle │ │ └── error_tracker.dart #
Consecutive Error Handling │ └── utils/ │ ├── coordinate_translator.dart # Raw →
Normalized → Screen │ ├── transform_calculator.dart # BoxFit.cover Math │ └──
logger.dart ├── di/ │ └── service_locator.dart # GetIt DI Setup ├── domain/ │
└── models/ │ ├── motion_data.dart # RawLandmark, NormalizedLandmark,
TimestampedPose │ ├── pose_session.dart # Session Container │ └──
session_metrics.dart # Pipeline Metrics └── presentation/ ├── bloc/ │ ├──
pose_detection_bloc.dart # Orchestration only (~220 Zeilen) │ ├──
pose_detection_event.dart │ └── pose_detection_state.dart ├── pages/ │ ├──
dashboard_page.dart # Minimaler Einstieg │ └── capture_page.dart # Hauptseite
mit Minimal/Detail Toggle └── widgets/ ├── camera_preview_widget.dart #
Preview + Mirror für Front-Cam ├── pose_painter.dart # Skeleton + Confidence
Heatmap └── raw_data_view.dart # Landmark-Tabelle

---

Features implementiert

Core

- Interfaces für alle Services (Testbarkeit)
- Dependency Injection mit GetIt
- O(1) Ring Buffer (900 Poses)
- Front/Back Kamera-Wechsel
- Droppable Frame Processing (Back-Pressure Handling)
- Error Tracking mit Threshold

Daten-Modelle

- RawLandmark (Pixel-Koordinaten)
- NormalizedLandmark (0-1 Range, geräteunabhängig)
- TimestampedPose (mit Temporal Metadata: µs Timestamp, Delta Time)
- SessionMetrics (FPS, Latency, Drop Rate, Detection Rate)
- Confidence Helpers (avgConfidence, highConfidenceLandmarks,
  lowConfidenceLandmarks)

UI/Inspection Dashboard

- Minimal Mode: FPS | Latency | Confidence
- Detail Mode: Alle Metriken
- Confidence Heatmap im Skeleton (Grün >0.8, Gelb 0.5-0.8, Rot <0.5)
- Raw Data View (33 Landmarks mit x, y, z, confidence)
- Kamera-Toggle (Front/Back)
- Mirror-Effekt für Selfie-Cam
- Graue, minimalistische Palette

---

Verfügbare Metriken

Pipeline Performance

| Metrik         | Quelle                         | Bedeutung                          |
| -------------- | ------------------------------ | ---------------------------------- |
| FPS            | metrics.effectiveFps(duration) | Verarbeitete Frames/Sekunde        |
| E2E Latency    | metrics.lastEndToEndLatencyMs  | Frame-Capture → UI (visueller Lag) |
| ML Latency     | metrics.averageLatencyMs       | ML Kit Processing Time             |
| Drop Rate      | metrics.dropRate               | % verworfene Frames                |
| Detection Rate | metrics.detectionRate          | % Frames mit erkannter Pose        |

Pose Quality

| Metrik          | Quelle                       | Bedeutung                       |
| --------------- | ---------------------------- | ------------------------------- |
| Avg Confidence  | pose.avgConfidence           | Durchschnitt aller 33 Landmarks |
| High Conf Count | pose.highConfidenceLandmarks | Landmarks >0.8                  |
| Low Conf Count  | pose.lowConfidenceLandmarks  | Landmarks <0.5                  |

Temporal (pro Pose)

| Metrik      | Quelle               | Bedeutung               |
| ----------- | -------------------- | ----------------------- |
| Frame Index | pose.frameIndex      | Sequentielle Nummer     |
| Timestamp   | pose.timestampMicros | Sensor-Zeit in µs       |
| Delta Time  | pose.deltaTimeMicros | Zeit seit letztem Frame |

---

Nächste Schritte (geplant)

UI Verbesserung (vor Domain Layer)

- Performance vs Pose Quality trennen in der Anzeige
- Body Region Breakdown (Upper/Lower/Core Confidence)
- Vorbereitung für Movement Data Layer (Winkel, Abstände)

Domain Layer (Fitness/Physio)

- Winkel-Berechnung (Knie, Hüfte, Schulter)
- Bewegungsphasen-Erkennung (runter/halten/hoch)
- Rep Counter
- Form-Feedback

---

Technische Details

Landmark Schema (ML Kit 33 Punkte)

0: Nose, 1-2: Eyes, 3-4: Ears, 5-6: Mouth 11-12: Shoulders, 13-14: Elbows,
15-16: Wrists 17-22: Hands (Pinky, Index, Thumb) 23-24: Hips, 25-26: Knees,
27-28: Ankles 29-32: Feet (Heel, Toe)

Koordinatensysteme

- Raw: Pixel im Kamerabild
- Normalized: 0-1 (geräteunabhängig)
- Screen: Widget-Koordinaten (nach BoxFit.cover Transform)

Performance-Ziele

- FPS: ≥25
- E2E Latency: <50ms
- Drop Rate: <5%

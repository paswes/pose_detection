import 'package:flutter/material.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// Comprehensive documentation page for developers.
class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlaygroundTheme.background,
      appBar: AppBar(
        backgroundColor: PlaygroundTheme.surface,
        title: const Text(
          'Developer Documentation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PlaygroundTheme.spacingLg),
        children: const [
          _SectionTitle('Overview'),
          _DocSection(
            title: 'Architecture',
            content: '''
This Motion Tracking system is built with Clean Architecture principles:

• **Core Layer**: Infrastructure services (camera, ML Kit, smoothing)
• **Domain Layer**: Business models and motion analysis
• **Presentation Layer**: BLoC state management and UI

**Key Design Principles:**
• Provider-agnostic: Abstracted from ML Kit, can swap to MediaPipe
• Exercise-agnostic: No hardcoded exercises, pure geometric calculations
• iOS-only: Optimized for iOS camera and ML Kit performance
''',
          ),

          _Divider(),
          _SectionTitle('Configuration Reference'),

          _DocSection(
            title: 'PoseDetectionConfig',
            subtitle: 'lib/core/config/pose_detection_config.dart',
            content: '''
Central configuration for the pose detection pipeline.

**Factory Presets:**
• `defaultConfig()` - Balanced settings for general use
• `smoothVisuals()` - More smoothing, ideal for UI presentation
• `responsive()` - Less smoothing, minimal lag for real-time feedback
• `raw()` - No smoothing, raw ML output for debugging
• `highPrecision()` - Strict confidence filtering for precision apps
''',
          ),

          _ParamTable(
            title: 'Smoothing Parameters (OneEuroFilter)',
            params: [
              _Param('smoothingEnabled', 'bool', 'true',
                  'Enable/disable landmark position smoothing'),
              _Param('smoothingMinCutoff', 'double', '1.0',
                  'Min cutoff frequency (0.1-10.0). Lower = more smoothing but more lag'),
              _Param('smoothingBeta', 'double', '0.007',
                  'Speed coefficient (0.0-1.0). Higher = less lag during fast movements'),
              _Param('smoothingDerivativeCutoff', 'double', '1.0',
                  'Derivative cutoff (0.1-10.0). Controls speed estimation smoothing'),
            ],
          ),

          _ParamTable(
            title: 'Confidence Thresholds',
            params: [
              _Param('highConfidenceThreshold', 'double', '0.8',
                  'Landmarks above this are considered reliable (green)'),
              _Param('lowConfidenceThreshold', 'double', '0.5',
                  'Landmarks below this may be unreliable (yellow)'),
              _Param('minConfidenceThreshold', 'double', '0.3',
                  'Minimum confidence to include a landmark'),
              _Param('filterLowConfidenceLandmarks', 'bool', 'false',
                  'Whether to filter out low confidence landmarks'),
            ],
          ),

          _ParamTable(
            title: 'Performance Settings',
            params: [
              _Param('maxConsecutiveErrors', 'int', '10',
                  'Max consecutive errors before stopping capture'),
              _Param('fpsWindowMs', 'int', '1000',
                  'Window size for FPS calculation (milliseconds)'),
              _Param('fpsBufferSize', 'int', '60',
                  'Max frames to track for FPS calculation'),
            ],
          ),

          _ParamTable(
            title: 'Latency Thresholds',
            params: [
              _Param('latencyThresholds.excellent', 'double', '50.0',
                  'Green indicator threshold (ms)'),
              _Param('latencyThresholds.acceptable', 'double', '100.0',
                  'Yellow indicator threshold (ms)'),
              _Param('latencyThresholds.warning', 'double', '150.0',
                  'Orange threshold. Above = red (ms)'),
            ],
          ),

          _Divider(),

          _DocSection(
            title: 'MotionAnalyzerConfig',
            subtitle: 'lib/domain/motion/services/motion_analyzer.dart',
            content: '''
Configuration for motion analysis features.

**Factory Presets:**
• `defaultConfig()` - All features enabled, 30-frame history
• `minimal()` - Angles only, no history or velocities (lowest CPU)
• `fullAnalysis()` - Extended 60-frame history for detailed analysis
• `romFocused()` - ROM tracking with 120-frame history
• `velocityFocused()` - Speed analysis with responsive smoothing
''',
          ),

          _ParamTable(
            title: 'Motion Analysis Parameters',
            params: [
              _Param('trackAngles', 'bool', 'true',
                  'Enable joint angle calculation'),
              _Param('trackVelocities', 'bool', 'true',
                  'Enable landmark velocity tracking'),
              _Param('trackRom', 'bool', 'true',
                  'Enable range of motion tracking'),
              _Param('maintainHistory', 'bool', 'true',
                  'Keep pose history for temporal analysis'),
              _Param('historyCapacity', 'int', '30',
                  'Max poses in history buffer (30-120)'),
              _Param('use3DAngles', 'bool', 'true',
                  'Use 3D angle calculations (vs 2D)'),
              _Param('minConfidence', 'double', '0.3',
                  'Min confidence for motion calculations'),
              _Param('velocitySmoothingFactor', 'double', '0.3',
                  'Velocity smoothing (0=none, 1=full)'),
            ],
          ),

          _Divider(),
          _SectionTitle('Data Models'),

          _DocSection(
            title: 'DetectedPose',
            subtitle: 'lib/domain/models/detected_pose.dart',
            content: '''
Container for a single pose detection result.

**Properties:**
• `landmarks` - List of 33 Landmark objects (ML Kit schema)
• `imageSize` - Size of the source camera image
• `timestampMicros` - Detection timestamp (microsecond precision)
• `avgConfidence` - Computed average across all landmarks

**Methods:**
• `getLandmarkById(int id)` - Get specific landmark (0-32)
• `getConfidentLandmarks(double minConf)` - Filter by confidence
• `getBoundingBox()` - Bounding rectangle of pose
• `getCenterOfMass()` - Calculated body center point
''',
          ),

          _DocSection(
            title: 'Landmark',
            subtitle: 'lib/domain/models/landmark.dart',
            content: '''
Single body landmark with position and confidence.

**Properties:**
• `id` - Landmark index (0-32 for ML Kit)
• `x, y` - Image space coordinates (pixels)
• `z` - Depth relative to hip midpoint
• `confidence` - ML model confidence (0.0-1.0)
''',
          ),

          _DocSection(
            title: 'LandmarkType Enum',
            subtitle: 'lib/domain/models/landmark_type.dart',
            content: '''
All 33 ML Kit landmarks with semantic names:

**Face (0-10):** nose, leftEyeInner, leftEye, leftEyeOuter, rightEyeInner, rightEye, rightEyeOuter, leftEar, rightEar, mouthLeft, mouthRight

**Upper Body (11-22):** leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist, leftPinky, rightPinky, leftIndex, rightIndex, leftThumb, rightThumb

**Lower Body (23-32):** leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle, leftHeel, rightHeel, leftFootIndex, rightFootIndex
''',
          ),

          _DocSection(
            title: 'BodyJoint Enum',
            subtitle: 'lib/domain/models/body_joint.dart',
            content: '''
Semantic joint definitions for angle calculations.

**Upper Body Joints:**
• `leftElbow` / `rightElbow` - Shoulder → Elbow → Wrist
• `leftShoulder` / `rightShoulder` - Elbow → Shoulder → Hip

**Lower Body Joints:**
• `leftHip` / `rightHip` - Shoulder → Hip → Knee
• `leftKnee` / `rightKnee` - Hip → Knee → Ankle
• `leftAnkle` / `rightAnkle` - Knee → Ankle → Heel

**Torso/Spine:**
• `leftTorsoLean` / `rightTorsoLean` - Body tilt measurement
• `neckLean` - Head forward lean

**Grouped Accessors:**
• `primaryJoints` - 8 most important joints
• `pairedJoints` - Left/right pairs for symmetry
• `upperBodyJoints` / `lowerBodyJoints`
''',
          ),

          _Divider(),
          _SectionTitle('Motion Analysis Data'),

          _DocSection(
            title: 'JointAngle',
            subtitle: 'lib/domain/motion/models/joint_angle.dart',
            content: '''
Angle measured at a joint vertex with three landmarks.

**Properties:**
• `radians` - Angle in radians (0 to π)
• `degrees` - Converted to 0-180°
• `normalized` - 0.0 to 1.0 (0=flexed, 1=extended)
• `confidence` - Average of three landmark confidences
• `timestamp` - Microsecond precision timestamp

**Methods:**
• `isApproximately(angle, tolerance)` - Compare angles
• `isInRange(min, max)` - Check bounds
• `isHighConfidence` - True if confidence ≥ 0.8
''',
          ),

          _DocSection(
            title: 'Velocity',
            subtitle: 'lib/domain/motion/models/velocity.dart',
            content: '''
Movement speed of a tracked landmark.

**Properties:**
• `pointId` - Landmark ID (0-32)
• `velocity` - 3D Vector (x, y, z in units/second)
• `speed` - Magnitude of velocity (units/second)
• `speed2D` - Ignores Z component
• `direction` - Normalized velocity vector
• `deltaTimeSeconds` - Time delta used for calculation
• `confidence` - Based on landmark confidence

**Speed Categories:**
• `stationary` - < 50 units/s
• `slow` - 50-200 units/s
• `moderate` - 200-500 units/s
• `fast` - 500-1000 units/s
• `veryFast` - > 1000 units/s

**Direction Methods:**
• `isMovingUp()` / `isMovingDown()` - Y-axis
• `isMovingLeft()` / `isMovingRight()` - X-axis
• `isMovingForward()` / `isMovingBackward()` - Z-axis (depth)
''',
          ),

          _DocSection(
            title: 'AngularVelocity',
            subtitle: 'lib/domain/motion/models/velocity.dart',
            content: '''
Rate of angle change for a joint.

**Properties:**
• `jointId` - Joint identifier string
• `radiansPerSecond` - Angular speed
• `degreesPerSecond` - Easier to interpret
• `isFlexing` - Angle decreasing
• `isExtending` - Angle increasing
''',
          ),

          _DocSection(
            title: 'RangeOfMotion',
            subtitle: 'lib/domain/motion/models/range_of_motion.dart',
            content: '''
Accumulated min/max angles over a session.

**Properties:**
• `minRadians` / `minDegrees` - Smallest angle observed
• `maxRadians` / `maxDegrees` - Largest angle observed
• `rangeRadians` / `rangeDegrees` - Total ROM (max - min)
• `midpointDegrees` - Center of the range
• `sampleCount` - Number of measurements
• `averageConfidence` - Quality metric
• `durationSeconds` - Tracking duration

**ROM Categories:**
• `minimal` - < 10° (essentially static)
• `limited` - 10-30°
• `moderate` - 30-60°
• `good` - 60-90°
• `full` - > 90°

**Methods:**
• `hasMeaningfulData` - Has samples AND range > 0.01 rad
• `normalizedPosition(angle)` - Where current angle sits (0-1)
• `contains(angle)` - Is within observed range
• `merge(other)` - Combine ROM data from sessions
''',
          ),

          _Divider(),
          _SectionTitle('Performance Metrics'),

          _DocSection(
            title: 'DetectionMetrics',
            subtitle: 'lib/domain/models/detection_metrics.dart',
            content: '''
Real-time performance metrics.

**Properties:**
• `fps` - Frames per second (double)
• `latencyMs` - End-to-end processing latency (double)

**Color Coding (Playground UI):**

**FPS:**
• Green: ≥ 25 fps (excellent)
• Yellow: ≥ 15 fps (acceptable)
• Red: < 15 fps (poor)

**Latency:**
• Green: < 50ms (excellent)
• Yellow: < 100ms (acceptable)
• Orange: < 150ms (warning)
• Red: ≥ 150ms (poor)

**Confidence:**
• Green: > 0.8 (high)
• Yellow: > 0.5 (medium)
• Red: ≤ 0.5 (low)
''',
          ),

          _DocSection(
            title: 'PlaygroundMetrics',
            subtitle: 'lib/presentation/bloc/playground/playground_state.dart',
            content: '''
Extended metrics for the Playground UI.

**Properties:**
• `detection` - Standard DetectionMetrics
• `poseCount` - Total poses detected in session
• `droppedFrames` - Frames skipped due to backlog
• `isStationary` - Body movement state
• `sessionStartTime` - When capture started
• `sessionDurationSeconds` - Elapsed time
''',
          ),

          _Divider(),
          _SectionTitle('OneEuroFilter Explained'),

          _DocSection(
            title: 'What is OneEuroFilter?',
            content: '''
A noise-reduction filter designed for real-time signal processing, particularly human input and motion tracking.

**Problem it Solves:**
Raw landmark positions from ML models contain jitter (high-frequency noise). This causes skeleton overlays to shake even when the person is still.

**How it Works:**
Adaptive low-pass filter that:
• Reduces jitter when movement is slow
• Allows fast movements to pass through with minimal lag

**Parameters Explained:**

**minCutoff (Default: 1.0)**
Controls baseline smoothing amount.
• Lower (0.1-0.5): More smoothing, more lag
• Higher (2.0-10.0): Less smoothing, less lag
• Use lower for smooth visuals, higher for responsiveness

**beta (Default: 0.007)**
Speed coefficient - how much speed affects filtering.
• Lower (0.001-0.005): Consistent smoothing regardless of speed
• Higher (0.01-0.1): Quick movements get less smoothing
• Use higher if fast movements feel laggy

**derivativeCutoff (Default: 1.0)**
Controls smoothing of the speed estimation itself.
• Lower: Smoother speed estimation
• Higher: More responsive speed estimation
• Usually leave at 1.0 unless fine-tuning
''',
          ),

          _Divider(),
          _SectionTitle('Usage Examples'),

          _CodeBlock(
            title: 'Basic Pose Detection',
            code: '''
// In your BLoC or service
final result = await poseDetector.detectPose(cameraImage);
if (result.pose != null) {
  // Access landmarks
  final nose = result.pose!.getLandmarkById(0);
  print('Nose at: (\${nose?.x}, \${nose?.y})');

  // Get average confidence
  final quality = result.pose!.avgConfidence;
}
''',
          ),

          _CodeBlock(
            title: 'Motion Analysis',
            code: '''
// Create analyzer
final analyzer = MotionAnalyzer(
  config: MotionAnalyzerConfig.defaultConfig(),
);
analyzer.startSession();

// Analyze each frame
final motionResult = analyzer.analyze(detectedPose);

// Access joint angles
final elbowAngle = motionResult.angles['11_13_15'];
print('Left elbow: \${elbowAngle?.degrees}°');

// Access velocities
final wristSpeed = motionResult.velocities[15];
print('Wrist speed: \${wristSpeed?.speed} px/s');

// Access ROM
final kneeRom = motionResult.rangeOfMotion['23_25_27'];
print('Knee ROM: \${kneeRom?.rangeDegrees}°');
''',
          ),

          _CodeBlock(
            title: 'Using BodyJoint Enum',
            code: '''
// Calculate angle using semantic joint
final angle = angleCalculator.calculateFromBodyJoint(
  pose: detectedPose,
  joint: BodyJoint.leftElbow,
);

// Get all primary joint angles
final angles = angleCalculator.calculateAllPrimaryAngles(
  pose: detectedPose,
);

// Iterate paired joints for symmetry check
for (final (left, right) in BodyJoint.pairedJoints) {
  final leftAngle = angles[left.jointId];
  final rightAngle = angles[right.jointId];
  final diff = (leftAngle?.degrees ?? 0) - (rightAngle?.degrees ?? 0);
  print('\${left.displayName} asymmetry: \${diff.abs()}°');
}
''',
          ),

          _CodeBlock(
            title: 'Dynamic Config Changes',
            code: '''
// In PlaygroundBloc
void _updatePoseConfig(PoseDetectionConfig config) {
  // Recreate smoother with new config
  _poseSmoother.dispose();
  _poseSmoother = PoseSmoother(config: config);

  emit(state.copyWith(poseConfig: config));
}

// Apply a preset
add(ApplyPresetEvent(ConfigPreset.smoothVisuals));

// Custom config adjustment
add(UpdatePoseConfigEvent(
  state.poseConfig.copyWith(
    smoothingMinCutoff: 0.5,
    smoothingBeta: 0.01,
  ),
));
''',
          ),

          SizedBox(height: PlaygroundTheme.spacingXl * 2),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: PlaygroundTheme.spacingLg,
        bottom: PlaygroundTheme.spacingMd,
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: PlaygroundTheme.accent,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _DocSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String content;

  const _DocSection({
    required this.title,
    this.subtitle,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: PlaygroundTheme.spacingMd),
      padding: const EdgeInsets.all(PlaygroundTheme.spacingMd),
      decoration: BoxDecoration(
        color: PlaygroundTheme.surface,
        borderRadius: BorderRadius.circular(PlaygroundTheme.radiusMd),
        border: Border.all(color: PlaygroundTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PlaygroundTheme.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: PlaygroundTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: PlaygroundTheme.spacingSm),
          _MarkdownText(content),
        ],
      ),
    );
  }
}

class _MarkdownText extends StatelessWidget {
  final String text;

  const _MarkdownText(this.text);

  @override
  Widget build(BuildContext context) {
    final lines = text.trim().split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          return const SizedBox(height: 8);
        }

        // Bold text with **
        if (trimmed.contains('**')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _parseBoldText(trimmed),
          );
        }

        // Bullet point
        if (trimmed.startsWith('•')) {
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: PlaygroundTheme.textMuted)),
                Expanded(child: _parseBoldText(trimmed.substring(1).trim())),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            trimmed,
            style: const TextStyle(
              fontSize: 12,
              color: PlaygroundTheme.textSecondary,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _parseBoldText(String text) {
    final parts = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        parts.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            fontSize: 12,
            color: PlaygroundTheme.textSecondary,
            height: 1.5,
          ),
        ));
      }
      parts.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: PlaygroundTheme.textPrimary,
          height: 1.5,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      parts.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          fontSize: 12,
          color: PlaygroundTheme.textSecondary,
          height: 1.5,
        ),
      ));
    }

    return RichText(text: TextSpan(children: parts));
  }
}

class _ParamTable extends StatelessWidget {
  final String title;
  final List<_Param> params;

  const _ParamTable({required this.title, required this.params});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: PlaygroundTheme.spacingMd),
      decoration: BoxDecoration(
        color: PlaygroundTheme.surface,
        borderRadius: BorderRadius.circular(PlaygroundTheme.radiusMd),
        border: Border.all(color: PlaygroundTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(PlaygroundTheme.spacingMd),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PlaygroundTheme.border),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PlaygroundTheme.textPrimary,
              ),
            ),
          ),
          ...params.map((p) => _ParamRow(param: p)),
        ],
      ),
    );
  }
}

class _Param {
  final String name;
  final String type;
  final String defaultValue;
  final String description;

  const _Param(this.name, this.type, this.defaultValue, this.description);
}

class _ParamRow extends StatelessWidget {
  final _Param param;

  const _ParamRow({required this.param});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PlaygroundTheme.spacingMd),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PlaygroundTheme.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  param.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: PlaygroundTheme.accent,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: PlaygroundTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
                ),
                child: Text(
                  param.type,
                  style: const TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    color: PlaygroundTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                param.defaultValue,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: PlaygroundTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            param.description,
            style: const TextStyle(
              fontSize: 11,
              color: PlaygroundTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String title;
  final String code;

  const _CodeBlock({required this.title, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: PlaygroundTheme.spacingMd),
      decoration: BoxDecoration(
        color: PlaygroundTheme.surface,
        borderRadius: BorderRadius.circular(PlaygroundTheme.radiusMd),
        border: Border.all(color: PlaygroundTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(PlaygroundTheme.spacingMd),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PlaygroundTheme.border),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, size: 14, color: PlaygroundTheme.textMuted),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PlaygroundTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(PlaygroundTheme.spacingMd),
            color: const Color(0xFF0D1117),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code.trim(),
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFFE6EDF3),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: PlaygroundTheme.spacingLg),
      height: 1,
      color: PlaygroundTheme.border,
    );
  }
}

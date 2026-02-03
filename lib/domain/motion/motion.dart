/// Human Motion Tracking Domain Layer
///
/// This library provides exercise-agnostic motion analysis capabilities:
/// - Joint angle calculations
/// - Velocity tracking
/// - Range of motion analysis
/// - Pose sequence management
///
/// All components are provider-agnostic and can work with any pose
/// detection backend (ML Kit, MediaPipe, custom models, etc.)
library;

// Models
export 'models/joint_angle.dart';
export 'models/pose_sequence.dart';
export 'models/range_of_motion.dart';
export 'models/vector3.dart';
export 'models/velocity.dart';

// Services
export 'services/angle_calculator.dart';
export 'services/motion_analyzer.dart';
export 'services/range_of_motion_analyzer.dart';
export 'services/velocity_tracker.dart';

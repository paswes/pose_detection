import 'package:pose_detection/core/domain/models/detected_pose.dart';

abstract class IPersonValidator {
  bool validate(DetectedPose? pose);
}

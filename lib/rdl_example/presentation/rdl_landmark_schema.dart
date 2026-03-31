import 'package:pose_detection/core/config/landmark_schema.dart';

/// Landmarks relevant for Romanian Deadlift analysis.
///
/// Keeps the kinetic chain from shoulders to ankles:
/// shoulders, elbows, wrists, hips, knees, ankles.
const rdlLandmarkIds = <int>{
  LandmarkSchema.leftShoulder,
  LandmarkSchema.rightShoulder,
  LandmarkSchema.leftElbow,
  LandmarkSchema.rightElbow,
  LandmarkSchema.leftWrist,
  LandmarkSchema.rightWrist,
  LandmarkSchema.leftHip,
  LandmarkSchema.rightHip,
  LandmarkSchema.leftKnee,
  LandmarkSchema.rightKnee,
  LandmarkSchema.leftAnkle,
  LandmarkSchema.rightAnkle,
};

/// Reduced schema for Romanian Deadlift analysis.
///
/// Only includes the kinetic chain landmarks and connections
/// relevant for RDL form: torso, arms (to wrist), legs (to ankle).
const rdlSchema = LandmarkSchema(
  landmarkCount: 33,
  landmarkNames: [
    'Nose', // 0
    'Left Eye Inner', // 1
    'Left Eye', // 2
    'Left Eye Outer', // 3
    'Right Eye Inner', // 4
    'Right Eye', // 5
    'Right Eye Outer', // 6
    'Left Ear', // 7
    'Right Ear', // 8
    'Left Mouth', // 9
    'Right Mouth', // 10
    'Left Shoulder', // 11
    'Right Shoulder', // 12
    'Left Elbow', // 13
    'Right Elbow', // 14
    'Left Wrist', // 15
    'Right Wrist', // 16
    'Left Pinky', // 17
    'Right Pinky', // 18
    'Left Index', // 19
    'Right Index', // 20
    'Left Thumb', // 21
    'Right Thumb', // 22
    'Left Hip', // 23
    'Right Hip', // 24
    'Left Knee', // 25
    'Right Knee', // 26
    'Left Ankle', // 27
    'Right Ankle', // 28
    'Left Heel', // 29
    'Right Heel', // 30
    'Left Foot Index', // 31
    'Right Foot Index', // 32
  ],
  skeletonConnections: [
    [LandmarkSchema.leftShoulder, LandmarkSchema.rightShoulder],
    [LandmarkSchema.leftShoulder, LandmarkSchema.leftHip],
    [LandmarkSchema.rightShoulder, LandmarkSchema.rightHip],
    [LandmarkSchema.leftHip, LandmarkSchema.rightHip],
    [LandmarkSchema.leftShoulder, LandmarkSchema.leftElbow],
    [LandmarkSchema.leftElbow, LandmarkSchema.leftWrist],
    [LandmarkSchema.rightShoulder, LandmarkSchema.rightElbow],
    [LandmarkSchema.rightElbow, LandmarkSchema.rightWrist],
    [LandmarkSchema.leftHip, LandmarkSchema.leftKnee],
    [LandmarkSchema.leftKnee, LandmarkSchema.leftAnkle],
    [LandmarkSchema.rightHip, LandmarkSchema.rightKnee],
    [LandmarkSchema.rightKnee, LandmarkSchema.rightAnkle],
  ],
);

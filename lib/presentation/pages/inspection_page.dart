import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/di/service_locator.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';
import 'package:pose_detection/presentation/bloc/inspection/inspection_bloc.dart';
import 'package:pose_detection/presentation/bloc/inspection/inspection_event.dart';
import 'package:pose_detection/presentation/bloc/inspection/inspection_state.dart';
import 'package:pose_detection/presentation/widgets/inspection/performance_tab.dart';
import 'package:pose_detection/presentation/widgets/inspection/motion_tab.dart';

/// Dedicated inspection page for debugging and development
/// Shows real-time performance and motion metrics
class InspectionPage extends StatefulWidget {
  const InspectionPage({super.key});

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late InspectionBloc _inspectionBloc;
  StreamSubscription? _poseSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _inspectionBloc = sl<InspectionBloc>();

    // Subscribe to pose detection state changes
    final poseBloc = sl<PoseDetectionBloc>();
    _poseSubscription = poseBloc.stream.listen(_onPoseStateChanged);

    // Process current state if already detecting
    _onPoseStateChanged(poseBloc.state);
  }

  void _onPoseStateChanged(PoseDetectionState state) {
    if (state is Detecting) {
      _inspectionBloc.add(UpdateInspectionDataEvent(
        session: state.session,
        currentPose: state.currentPose,
      ));
    } else if (state is SessionSummary) {
      // Session ended
      _inspectionBloc.add(UpdateInspectionDataEvent(
        session: state.session,
        currentPose: null,
      ));
    }
  }

  @override
  void dispose() {
    _poseSubscription?.cancel();
    _tabController.dispose();
    _inspectionBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _inspectionBloc,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF888888)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Color(0xFF4CAF50), size: 20),
              SizedBox(width: 8),
              Text(
                'Inspection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF4CAF50),
            indicatorWeight: 2,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF666666),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.speed, size: 16),
                    SizedBox(width: 6),
                    Text('Performance'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.accessibility_new, size: 16),
                    SizedBox(width: 6),
                    Text('Motion'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: BlocBuilder<InspectionBloc, InspectionState>(
          builder: (context, state) {
            if (state is! InspectionActive) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF4CAF50),
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Waiting for pose data...',
                      style: TextStyle(color: Color(0xFF666666)),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Start a capture session to inspect',
                      style: TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                PerformanceTab(snapshot: state.snapshot),
                MotionTab(
                  snapshot: state.snapshot,
                  selectedLandmarkId: state.selectedLandmarkId,
                  onLandmarkSelected: (id) {
                    _inspectionBloc.add(SelectLandmarkEvent(id));
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// The data model representing a single clock-in session.
class WorkLog {
  final String id;
  final String userId;
  final String userName;
  final String site;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;

  WorkLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.site,
    required this.startTime,
    this.endTime,
    required this.status,
  });

  /// Factory constructor to create a WorkLog from a Firestore document.
  factory WorkLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return WorkLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown User',
      site: data['site'] ?? 'N/A',
      // Convert Firestore Timestamp to Dart DateTime
      startTime: data['startTime'] != null
          ? (data['startTime'] as Timestamp).toDate()
          : DateTime.now(), // Fallback to now if missing
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'active',
    );
  }

  /// Converts the WorkLog object back into a Map for Firestore updates.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'site': site,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status,
    };
  }

  /// Helper to get the duration of work in minutes.
  int get durationInMinutes {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes;
  }

  /// Helper to get the duration of work in hours for reporting.
  double get durationInHours {
    if (endTime == null) return 0.0;
    return endTime!.difference(startTime).inMinutes / 60.0;
  }
}

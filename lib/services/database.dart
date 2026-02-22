import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/work_log.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String appId = "clock-in-app-v1";

  // --- Collection Reference Helper ---
  CollectionReference get _logsRef => _db
      .collection('artifacts')
      .doc(appId)
      .collection('public')
      .doc('data')
      .collection('logs');

  // --- Employee Actions ---

  /// Starts a new work session
  Future<String> clockIn(String siteName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final doc = await _logsRef.add({
      'userId': user.uid,
      'userName': user.displayName ?? 'Worker_${user.uid.substring(0, 4)}',
      'site': siteName,
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'status': 'active',
    });

    return doc.id;
  }

  /// Ends an active work session
  Future<void> clockOut(String logId) async {
    await _logsRef.doc(logId).update({
      'endTime': FieldValue.serverTimestamp(),
      'status': 'completed',
    });
  }

  // --- Streams (For Real-time UI) ---

  /// Stream of all logs for the Admin Live Feed
  Stream<List<WorkLog>> streamAllLogs() {
    return _logsRef
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => WorkLog.fromFirestore(doc)).toList(),
        );
  }

  /// Stream of logs for the currently logged-in employee
  Stream<List<WorkLog>> streamCurrentEmployeeLogs() {
    final uid = _auth.currentUser?.uid;
    return _logsRef
        .where('userId', isEqualTo: uid)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => WorkLog.fromFirestore(doc)).toList(),
        );
  }

  // --- Reporting Logic ---

  /// Aggregates data for the Reporting View (Weekly Stats)
  Future<Map<String, double>> getWeeklyHoursPerEmployee() async {
    final snapshot = await _logsRef.get();
    Map<String, double> totals = {};

    for (var doc in snapshot.docs) {
      final log = WorkLog.fromFirestore(doc);
      if (log.endTime != null) {
        final hours = log.durationInHours;
        totals[log.userName] = (totals[log.userName] ?? 0) + hours;
      }
    }
    return totals;
  }
}

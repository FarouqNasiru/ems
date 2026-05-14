import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/work_log.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String appId;

  DatabaseService({this.appId = "clock-in-app-v1"});

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

  /// Deletes all logs and their screenshots (Admin only)
  Future<void> deleteAllLogs() async {
    try {
      debugPrint("ADMIN: Initiating full clear for appId: $appId");
      final snapshot = await _logsRef.get();
      print("Found ${snapshot.docs.length} logs to delete.");
      
      for (var doc in snapshot.docs) {
        // 1. Delete screenshots sub-collection
        final screenshots = await doc.reference.collection('screenshots').get();
        if (screenshots.docs.isNotEmpty) {
          final sBatch = _db.batch();
          for (var sDoc in screenshots.docs) {
            sBatch.delete(sDoc.reference);
          }
          await sBatch.commit();
        }

        // 2. Delete the log document itself
        await doc.reference.delete();
      }

      // Also clear daily_reports and weekly_summaries if they are part of the "history"
      final reportsRef = _db.collection('artifacts').doc(appId).collection('public').doc('data').collection('daily_reports');
      final reportsSnap = await reportsRef.get();
      for (var doc in reportsSnap.docs) {
        await doc.reference.delete();
      }

      final summariesRef = _db.collection('artifacts').doc(appId).collection('public').doc('data').collection('weekly_summaries');
      final summariesSnap = await summariesRef.get();
      for (var doc in summariesSnap.docs) {
        await doc.reference.delete();
      }

      print("Successfully cleared all logs and reports.");
    } catch (e) {
      print("Error in deleteAllLogs: $e");
      rethrow;
    }
  }
}

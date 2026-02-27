```
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../models/daily_report.dart';

// Pill colours reused from the daily report page palette
const List<Color> _pillColors = [
  Color(0xFF7C6FCD),
  Color(0xFF9067C6),
  Color(0xFF5B8DEF),
  Color(0xFF4AADDE),
  Color(0xFF36C7B0),
  Color(0xFF6E7CDE),
  Color(0xFF52B8F5),
];

class AdminWeeklyReportsPage extends StatefulWidget {
  final String appId;
  const AdminWeeklyReportsPage({super.key, required this.appId});

  @override
  State<AdminWeeklyReportsPage> createState() => _AdminWeeklyReportsPageState();
}

class _AdminWeeklyReportsPageState extends State<AdminWeeklyReportsPage> {
  // null = list view; non-null = detail view for that user
  Map<String, dynamic>? _selectedEmployee;
  List<DailyReport> _reports = [];
  bool _loadingReports = false;

  Future<void> _loadWeeklyReports(String userId) async {
    setState(() {
      _loadingReports = true;
      _reports = [];
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(widget.appId)
          .collection('public')
          .doc('data')
          .collection('daily_reports')
          .where('userId', isEqualTo: userId)
          .where('isWeeklySubmission', isEqualTo: true)
          .get();

      final fetchedReports = snap.docs
          .map((d) => DailyReport.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _reports = fetchedReports;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    } finally {
      setState(() => _loadingReports = false);
    }
  }

  void _downloadCSV(DailyReport report) async {
    try {
      final csvData = const ListToCsvConverter().convert(report.toCsvRows());
      final fileName = 'Weekly_Report_${report.userName}_${DateFormat('yyyy-MM-dd').format(report.date)}.csv';

      if (kIsWeb) {
        // Use url_launcher to trigger download via data URI for Web
        final encodedUri = Uri.dataFromString(
          csvData,
          mimeType: 'text/csv',
          encoding: utf8,
        );

        if (await canLaunchUrl(encodedUri)) {
          await launchUrl(encodedUri);
        } else {
          throw 'Could not launch $encodedUri';
        }
      } else {
        // Desktop/Mobile: Use FilePicker to save natively
        final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Weekly Report CSV',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
          bytes: utf8.encode(csvData),
        );

        if (outputFile != null) {
          // FilePicker with bytes handles saving on most platforms directly.
          // On Windows, if outputFile is a path, we might need writeAsBytes if bytes param wasn't enough,
          // but usually 'bytes' parameter in saveFile (for Web/Mobile) and its counterparts work.
          // For Windows, saveFile returns the path. If bytes were provided, it usually writes them.
          // Just in case or if bytes param is only for certain platforms:
          final file = File(outputFile);
          await file.writeAsBytes(utf8.encode(csvData));
        } else {
          // User cancelled
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        title: Text(
          _selectedEmployee == null
              ? 'Weekly Reports'
              : _selectedEmployee!['displayName'] ?? 'Employee',
        ),
        leading: _selectedEmployee != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedEmployee = null;
                  _reports = [];
                }),
              )
            : null,
      ),
      body: _selectedEmployee == null
          ? _buildEmployeeList()
          : _buildReportList(),
    );
  }

  // ─── Employee list ─────────────────────────────────────────────────────────
  Widget _buildEmployeeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No employees found.'));
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: users.length,
          itemBuilder: (context, i) {
            final data = users[i].data() as Map<String, dynamic>;
            final name = data['displayName'] ?? 'Unknown';
            final email = data['email'] ?? '';
            final pillColor = _pillColors[i % _pillColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => _selectedEmployee = data);
                    _loadWeeklyReports(data['uid'] ?? users[i].id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: pillColor,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF2D2D3A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF9094A6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Weekly report list ──────────────────────────────────────────────────
  Widget _buildReportList() {
    if (_loadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No weekly reports found.',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _reports.length,
      itemBuilder: (context, i) {
        final r = _reports[i];
        final dateStr = DateFormat('EEEE, MMM d, yyyy').format(r.date);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const Icon(Icons.calendar_today, color: Color(0xFF7C6FCD)),
            title: Text(
              'Week ending $dateStr',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Weekly Submission'),
            trailing: IconButton(
              icon: const Icon(Icons.download, color: Colors.green),
              onPressed: () => _downloadCSV(r),
              tooltip: 'Download CSV',
            ),
          ),
        );
      },
    );
  }
}

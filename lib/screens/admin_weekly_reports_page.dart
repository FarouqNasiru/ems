import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
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

      final fetchedReports =
          snap.docs.map((d) => DailyReport.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _reports = fetchedReports;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading reports: $e')));
      }
    } finally {
      setState(() => _loadingReports = false);
    }
  }

  void _downloadCSV(DailyReport weeklyReport) async {
    setState(() {
      _loadingReports = true;
    });

    try {
      // 1. Determine the week range (7 days ending on the report date)
      final endDate = weeklyReport.date;
      final startDate = endDate.subtract(const Duration(days: 6));

      // 2. Fetch ALL daily reports for this user in that range
      final snap = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(widget.appId)
          .collection('public')
          .doc('data')
          .collection('daily_reports')
          .where('userId', isEqualTo: weeklyReport.userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final reports =
          snap.docs.map((d) => DailyReport.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => a.date.compareTo(b.date)); // Chronological order

      // 3. Generate aggregated CSV
      final csvData = _generateFullWeeklyCsv(reports, weeklyReport);
      final fileName =
          'Weekly_Report_${weeklyReport.userName}_${DateFormat('yyyy-MM-dd').format(weeklyReport.date)}.csv';

      _showCsvDialog(csvData, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating aggregated CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  String _generateFullWeeklyCsv(
    List<DailyReport> reports,
    DailyReport summaryReport,
  ) {
    final List<List<dynamic>> rows = [];
    final df = DateFormat('yyyy-MM-dd');

    // Header
    rows.add(['FULL WEEKLY ACTIVITY REPORT']);
    rows.add(['Employee', summaryReport.userName]);
    rows.add(['Week Ending', df.format(summaryReport.date)]);
    rows.add(['Reports Included', reports.length.toString()]);
    rows.add([]);

    // Viral Mailers
    rows.add(['SECTION: Viral Mailers']);
    rows.add([
      'Date',
      'Name',
      'Site Name',
      'Sent To',
      'Clicks',
      'CTR',
      'Emails Clicked',
      'Frequency',
    ]);
    for (var r in reports) {
      for (var m in r.viralMailers) {
        rows.add([
          df.format(r.date),
          m.name,
          m.siteName,
          m.sentTo,
          m.clicks,
          m.ctr,
          m.emailsClicked,
          m.frequency,
        ]);
      }
    }
    rows.add([]);

    // Traffic Exchanges
    rows.add(['SECTION: Traffic Exchanges']);
    rows.add(['Date', 'Name', 'URL', 'Hits', 'Surf Count']);
    for (var r in reports) {
      for (var t in r.trafficExchanges) {
        rows.add([df.format(r.date), t.name, t.url, t.hits, t.surfCount]);
      }
    }
    rows.add([]);

    // Social Media
    rows.add(['SECTION: Social Media']);
    rows.add(['Date', 'Name', 'Post Link']);
    for (var r in reports) {
      for (var s in r.socialMedia) {
        rows.add([df.format(r.date), s.name, s.postLink]);
      }
    }
    rows.add([]);

    // Tracking Links
    rows.add(['SECTION: Tracking Links']);
    rows.add(['Date', 'URL', 'Total Hits', 'Top 3 Countries', 'Top 3 Sites']);
    for (var r in reports) {
      for (var l in r.trackingLinks) {
        rows.add([
          df.format(r.date),
          l.url,
          l.totalHits,
          l.top3Countries,
          l.top3Sites,
        ]);
      }
    }
    rows.add([]);

    // Weekly Mailer Stats
    rows.add(['SECTION: Weekly Mailer Stats']);
    rows.add([
      'Date',
      'Site Name',
      'Mailed This Week',
      'New Members',
      'Subscribed Members',
    ]);
    for (var r in reports) {
      for (var w in r.weeklyMailers) {
        rows.add([
          df.format(r.date),
          w.siteName,
          w.mailedThisWeek,
          w.newMembersThisWeek,
          w.subscribedMembersThisWeek,
        ]);
      }
    }
    rows.add([]);

    // Other Tasks
    rows.add(['SECTION: Daily Other Tasks']);
    rows.add(['Date', 'Task Description']);
    for (var r in reports) {
      if (r.otherTasks.trim().isNotEmpty) {
        rows.add([df.format(r.date), r.otherTasks]);
      }
    }
    rows.add([]);

    // Summary Section (from the weekly submission itself)
    rows.add(['SECTION: WEEKLY SUMMARY & REVIEW']);
    rows.add([
      'Key Tasks Completed',
      summaryReport.keyTasksCompleted.join('; '),
    ]);
    rows.add(['Goals for the Week', summaryReport.goalsForTheWeek.join('; ')]);
    rows.add([
      'Achievements / Wins',
      summaryReport.achievementsWins.join('; '),
    ]);
    rows.add([
      'Challenges / Obstacles',
      summaryReport.challengesObstacles.join('; '),
    ]);
    rows.add([
      'Solutions / Actions Taken',
      summaryReport.solutionsActionsTaken.join('; '),
    ]);
    rows.add(['Skills or Learning', summaryReport.skillsLearning.join('; ')]);
    rows.add([
      'Performance Rating',
      summaryReport.performanceRating.join('; '),
    ]);
    rows.add(['Goals for Next Week', summaryReport.goalsNextWeek.join('; ')]);
    rows.add(['Additional Notes', summaryReport.additionalNotes.join('; ')]);

    return const ListToCsvConverter().convert(rows);
  }

  void _showCsvDialog(String csv, String filename) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Export: $filename'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kIsWeb
                    ? 'You can copy the raw data or trigger a direct download.'
                    : 'Use "Copy" to grab the data (Direct download is Web-only).',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                height: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard!')),
              );
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
          if (kIsWeb)
            ElevatedButton.icon(
              onPressed: () async {
                final encoded = Uri.encodeComponent(csv);
                final url = 'data:text/csv;charset=utf-8,$encoded';
                try {
                  await launchUrl(
                    Uri.parse(url),
                    webOnlyWindowName: '_self',
                    mode: LaunchMode.externalApplication,
                  );
                  Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not trigger download. Please use "Copy".',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download File'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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

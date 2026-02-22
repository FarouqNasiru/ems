import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
  DailyReport? _weeklyReport;
  bool _loadingReport = false;

  Future<void> _loadWeeklyReport(String userId) async {
    setState(() {
      _loadingReport = true;
      _weeklyReport = null;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(widget.appId)
          .collection('public')
          .doc('data')
          .collection('daily_reports')
          .where('userId', isEqualTo: userId)
          .get();

      if (snap.docs.isNotEmpty) {
        // Filter and sort client-side to avoid composite index requirement
        final reports =
            snap.docs
                .map((d) => DailyReport.fromMap(d.id, d.data()))
                .where((r) => r.isWeeklySubmission)
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date)); // descending date

        if (reports.isNotEmpty) {
          setState(() {
            _weeklyReport = reports.first;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading report: $e')));
      }
    } finally {
      setState(() => _loadingReport = false);
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
                  _weeklyReport = null;
                }),
              )
            : null,
      ),
      body: _selectedEmployee == null
          ? _buildEmployeeList()
          : _buildReportDetail(),
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
                    _loadWeeklyReport(data['uid'] ?? users[i].id);
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

  // ─── Weekly report detail ──────────────────────────────────────────────────
  Widget _buildReportDetail() {
    if (_loadingReport) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_weeklyReport == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No weekly report submitted yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final r = _weeklyReport!;
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(r.date);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C6FCD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Week ending $dateStr',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Part 3 review fields
          _reviewCard('Key Tasks Completed', r.keyTasksCompleted),
          _reviewCard('Goals for the Week', r.goalsForTheWeek),
          _reviewCard('Achievements / Wins', r.achievementsWins),
          _reviewCard('Challenges / Obstacles', r.challengesObstacles),
          _reviewCard('Solutions / Actions Taken', r.solutionsActionsTaken),
          _reviewCard('Skills or Learning This Week', r.skillsLearning),
          _reviewCard('Overall Performance Self-Rating', r.performanceRating),
          _reviewCard('Goals for Next Week', r.goalsNextWeek),
          _reviewCard('Additional Notes', r.additionalNotes),

          if (r.otherTasks.trim().isNotEmpty)
            _reviewCard('Other Tasks', [r.otherTasks]),
        ],
      ),
    );
  }

  Widget _reviewCard(String title, List<String> items) {
    final filtered = items.where((s) => s.trim().isNotEmpty).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6FCD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF2D2D3A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...filtered.asMap().entries.map(
              (e) => Padding(
                padding: EdgeInsets.only(
                  bottom: e.key < filtered.length - 1 ? 6 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7C6FCD),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A4A5A),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

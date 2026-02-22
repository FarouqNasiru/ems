import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/daily_report.dart';

// --- Color palette for row pills (cycles through these) ---
const List<Color> _pillColors = [
  Color(0xFF7C6FCD), // purple
  Color(0xFF9067C6), // violet
  Color(0xFF5B8DEF), // blue
  Color(0xFF4AADDE), // sky
  Color(0xFF36C7B0), // teal
  Color(0xFF6E7CDE), // indigo
  Color(0xFF52B8F5), // light blue
];

class DailyReportPage extends StatefulWidget {
  final String appId;

  const DailyReportPage({super.key, required this.appId});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  DailyReport? _report;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateId = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final docId = "${user.uid}_$dateId";

    try {
      final doc = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(widget.appId)
          .collection('public')
          .doc('data')
          .collection('daily_reports')
          .doc(docId)
          .get();

      if (doc.exists) {
        setState(() {
          _report = DailyReport.fromMap(doc.id, doc.data()!);
        });
      } else {
        setState(() {
          _report = DailyReport.empty(
            user.uid,
            user.displayName ?? 'User',
            _selectedDate,
          );
          _report!.id = docId;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading report: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveReport({bool isWeekly = false}) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (isWeekly) _report!.isWeeklySubmission = true;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(widget.appId)
          .collection('public')
          .doc('data')
          .collection('daily_reports')
          .doc(_report!.id)
          .set(_report!.toMap());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isWeekly
                ? 'Weekly report submitted successfully!'
                : 'Report saved successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _report = null;
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        title: const Text("Daily Activity Report"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
          ? const Center(child: Text("Initializing..."))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        "Report for ${DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)}",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildSection("Viral Mailers", _buildViralMailersTable()),
                    const SizedBox(height: 24),
                    _buildSection(
                      "Traffic Exchanges",
                      _buildTrafficExchangesTable(),
                    ),
                    const SizedBox(height: 24),
                    _buildSection("Social Media", _buildSocialMediaTable()),
                    const SizedBox(height: 24),
                    _buildSection("Tracking Links", _buildTrackingLinksTable()),
                    const SizedBox(height: 24),
                    _buildSection(
                      "Part 2 — Weekly Mailer Stats",
                      _buildWeeklyMailersTable(),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      "Part 3 — Weekly Review",
                      _buildWeeklyReviewSection(),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      "Other Tasks",
                      TextFormField(
                        initialValue: _report!.otherTasks,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: "Describe other tasks performed...",
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onSaved: (val) => _report!.otherTasks = val ?? '',
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── Save / Submit button (Friday-aware) ──────────────────────────────────
  Widget _buildSaveButton() {
    final isFriday = _selectedDate.weekday == DateTime.friday;
    if (isFriday) {
      return ElevatedButton.icon(
        onPressed: () => _saveReport(isWeekly: true),
        icon: const Icon(Icons.send_rounded),
        label: const Text('SUBMIT REPORT FOR THE WHOLE WEEK'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2ECC71),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: () => _saveReport(),
      icon: const Icon(Icons.save),
      label: const Text('SAVE REPORT'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Section wrapper ───────────────────────────────────────────────────────
  Widget _buildSection(String title, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D3A),
            ),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  // ─── Shared table helpers ──────────────────────────────────────────────────

  /// Header row – plain light text, no background fill
  Widget _headerRow(List<String> headers, List<double> widths) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: List.generate(headers.length, (i) {
          return SizedBox(
            width: widths[i],
            child: Text(
              headers[i],
              textAlign: i == 0 ? TextAlign.left : TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9094A6),
                letterSpacing: 0.5,
              ),
            ),
          );
        }),
      ),
    );
  }

  /// A single data row with a colored pill label and editable cells
  Widget _dataRow({
    required int index,
    required String label,
    required List<double> widths,
    required List<Widget> cells,
  }) {
    final pillColor = _pillColors[index % _pillColors.length];
    final isEven = index % 2 == 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF7F8FC) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pill label
          SizedBox(
            width: widths[0],
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Data cells
          ...List.generate(cells.length, (i) {
            return SizedBox(
              width: widths[i + 1],
              child: Center(child: cells[i]),
            );
          }),
        ],
      ),
    );
  }

  // ─── Viral Mailers ─────────────────────────────────────────────────────────
  Widget _buildViralMailersTable() {
    const headers = [
      'Name',
      'Site Name',
      '# Sent',
      'Clicks',
      'CTR',
      'Emails Clicked',
      'Freq',
    ];
    const widths = [130.0, 160.0, 70.0, 70.0, 70.0, 110.0, 90.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(headers, widths),
          const Divider(height: 1, color: Color(0xFFE8E9F0)),
          const SizedBox(height: 4),
          ..._report!.viralMailers.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            return _dataRow(
              index: i,
              label: entry.name,
              widths: widths,
              cells: [
                _strInput(
                  entry.siteName,
                  (v) => entry.siteName = v,
                  width: 148,
                ),
                _intInput(entry.sentTo, (v) => entry.sentTo = v),
                _intInput(entry.clicks, (v) => entry.clicks = v),
                _dblInput(entry.ctr, (v) => entry.ctr = v),
                _intInput(entry.emailsClicked, (v) => entry.emailsClicked = v),
                _strInput(entry.frequency, (v) => entry.frequency = v),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Traffic Exchanges ─────────────────────────────────────────────────────
  Widget _buildTrafficExchangesTable() {
    const headers = ['Name', 'Site URL', 'Hits', 'Surf #'];
    const widths = [160.0, 200.0, 70.0, 70.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(headers, widths),
          const Divider(height: 1, color: Color(0xFFE8E9F0)),
          const SizedBox(height: 4),
          ..._report!.trafficExchanges.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            return _dataRow(
              index: i,
              label: entry.name,
              widths: widths,
              cells: [
                _strInput(entry.url, (v) => entry.url = v, width: 185),
                _intInput(entry.hits, (v) => entry.hits = v),
                _intInput(entry.surfCount, (v) => entry.surfCount = v),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Social Media ──────────────────────────────────────────────────────────
  Widget _buildSocialMediaTable() {
    const headers = ['Platform', 'Link to Post'];
    const widths = [140.0, 320.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(headers, widths),
          const Divider(height: 1, color: Color(0xFFE8E9F0)),
          const SizedBox(height: 4),
          ..._report!.socialMedia.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            return _dataRow(
              index: i,
              label: entry.name,
              widths: widths,
              cells: [
                _strInput(
                  entry.postLink,
                  (v) => entry.postLink = v,
                  width: 305,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Tracking Links ────────────────────────────────────────────────────────
  Widget _buildTrackingLinksTable() {
    const headers = [
      'Label',
      'URL',
      'Total Hits',
      'Top 3 Countries',
      'Top 3 Sites',
    ];
    const widths = [130.0, 200.0, 80.0, 160.0, 160.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(headers, widths),
          const Divider(height: 1, color: Color(0xFFE8E9F0)),
          const SizedBox(height: 4),
          ..._report!.trackingLinks.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            return _dataRow(
              index: i,
              label: 'Tracking Link ${i + 1}',
              widths: widths,
              cells: [
                _strInput(entry.url, (v) => entry.url = v, width: 185),
                _intInput(entry.totalHits, (v) => entry.totalHits = v),
                _strInput(
                  entry.top3Countries,
                  (v) => entry.top3Countries = v,
                  width: 145,
                ),
                _strInput(
                  entry.top3Sites,
                  (v) => entry.top3Sites = v,
                  width: 145,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Part 2: Weekly Mailer Stats ───────────────────────────────────────────
  Widget _buildWeeklyMailersTable() {
    const headers = [
      '#',
      'Name of Site',
      'Mailed This Week',
      'New Members This Week',
      'Subscribed Members',
    ];
    const widths = [40.0, 180.0, 140.0, 170.0, 150.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(headers, widths),
              const Divider(height: 1, color: Color(0xFFE8E9F0)),
              const SizedBox(height: 4),
              ..._report!.weeklyMailers.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                return _dataRow(
                  index: i,
                  label: '${i + 1}',
                  widths: widths,
                  cells: [
                    _strInput(
                      entry.siteName,
                      (v) => entry.siteName = v,
                      width: 165,
                    ),
                    _intInput(
                      entry.mailedThisWeek,
                      (v) => entry.mailedThisWeek = v,
                    ),
                    _intInput(
                      entry.newMembersThisWeek,
                      (v) => entry.newMembersThisWeek = v,
                    ),
                    _intInput(
                      entry.subscribedMembers,
                      (v) => entry.subscribedMembers = v,
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _report!.weeklyMailers.add(WeeklyMailerEntry());
              });
            },
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add Row'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7C6FCD),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Part 3: Weekly Review ─────────────────────────────────────────────────
  Widget _buildWeeklyReviewSection() {
    final fields = [
      _ReviewField('Key Tasks Completed', _report!.keyTasksCompleted),
      _ReviewField('Goals for the Week', _report!.goalsForTheWeek),
      _ReviewField('Achievements / Wins', _report!.achievementsWins),
      _ReviewField('Challenges / Obstacles', _report!.challengesObstacles),
      _ReviewField('Solutions / Actions Taken', _report!.solutionsActionsTaken),
      _ReviewField('Skills or Learning This Week', _report!.skillsLearning),
      _ReviewField(
        'Overall Performance Self-Rating',
        _report!.performanceRating,
      ),
      _ReviewField('Goals for Next Week', _report!.goalsNextWeek),
      _ReviewField('Additional Notes', _report!.additionalNotes),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.map((f) => _buildReviewField(f.label, f.list)).toList(),
    );
  }

  Widget _buildReviewField(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF2D2D3A),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(items.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: items[i],
                      maxLines: null,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter $label...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE1EE),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE1EE),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF7C6FCD),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSaved: (v) => items[i] = v ?? '',
                    ),
                  ),
                  if (items.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Color(0xFFCC5555),
                        size: 20,
                      ),
                      onPressed: () => setState(() => items.removeAt(i)),
                      tooltip: 'Remove',
                      padding: const EdgeInsets.only(left: 6),
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => items.add('')),
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: Text('Add $label'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7C6FCD),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Input helper widgets ──────────────────────────────────────────────────

  Widget _intInput(int value, Function(int) onChanged) {
    return SizedBox(
      width: 56,
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: _inputDecoration(),
        onSaved: (v) => onChanged(int.tryParse(v ?? '0') ?? 0),
      ),
    );
  }

  Widget _dblInput(double value, Function(double) onChanged) {
    return SizedBox(
      width: 56,
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: _inputDecoration(),
        onSaved: (v) => onChanged(double.tryParse(v ?? '0') ?? 0.0),
      ),
    );
  }

  Widget _strInput(
    String value,
    Function(String) onChanged, {
    double width = 140,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: value,
        textAlign: TextAlign.center,
        decoration: _inputDecoration(),
        onSaved: (v) => onChanged(v ?? ''),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFDDE1EE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFDDE1EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF7C6FCD), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

/// Simple data holder for Part 3 review fields.
class _ReviewField {
  final String label;
  final List<String> list;
  const _ReviewField(this.label, this.list);
}

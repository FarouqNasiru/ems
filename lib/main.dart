import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert'; // Added for Base64 decoding
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fl_chart/fl_chart.dart'; // Charting Library

// Services & Screens
import 'package:ems/services/auth_service.dart';
import 'package:ems/screens/login_page.dart';
import 'package:ems/screens/daily_report_page.dart';
import 'package:ems/screens/admin_weekly_reports_page.dart';

/**
 * WorkLog Pro - Main Application File
 * * Features:
 * - Email/Password Authentication
 * - Real-time Clock In/Out (Employee Portal)
 * - Live Activity Monitoring (Admin Dashboard)
 * - Weekly Hours Aggregation & Reporting
 */

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '', // Load from env
      appId: "1:188575575343:web:87b2a91665994c9f3805da",
      messagingSenderId: "188575575343",
      projectId: "nexxgenva-2d149",
      authDomain: "nexxgenva-2d149.firebaseapp.com",
      storageBucket: "nexxgenva-2d149.firebasestorage.app",
      measurementId: "G-TJHKJ2NEZQ",
    ),
  );
  runApp(const WorkLogApp());
}

class WorkLogApp extends StatefulWidget {
  const WorkLogApp({super.key});

  @override
  State<WorkLogApp> createState() => _WorkLogAppState();

  static _WorkLogAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_WorkLogAppState>()!;
}

class _WorkLogAppState extends State<WorkLogApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkLog Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Light grey bg
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        cardColor: Colors.white,
        dividerColor: Colors.grey[200],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E2E), // Deep dark blue
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          surface: const Color(0xFF2D2D44), // Card bg in dark mode
        ),
        cardColor: const Color(0xFF2D2D44),
        dividerColor: Colors.grey[800],
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // User is logged in, ensure their document exists
          return FutureBuilder(
            future: AuthService().ensureUserDocument(),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return const MainNavigationPage();
            },
          );
        }
        return const LoginPage();
      },
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  final String appId =
      'clock-in-app-v1'; // Hardcoded for simplified access in child widgets
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  final String _appId = "clock-in-app-v1"; // Consistent with previous specs

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar for Desktop, Bottom Nav for Mobile
          if (isDesktop)
            Container(
              width: 280,
              color: Colors.white,
              child: Column(
                children: [
                  // ── Scrollable top section ──────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brand Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[600],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.widgets,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "WorkLog Pro",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Weekly Progress Widget
                          if (FirebaseAuth.instance.currentUser != null)
                            FutureBuilder<String>(
                              future: AuthService().getUserRole(),
                              builder: (context, roleSnapshot) {
                                if (!roleSnapshot.hasData)
                                  return const SizedBox();

                                final isAdmin = roleSnapshot.data == 'admin';
                                final currentUser =
                                    FirebaseAuth.instance.currentUser!;

                                if (isAdmin) {
                                  return Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 260,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Team Progress",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .snapshots(),
                                            builder: (context, userSnapshot) {
                                              if (!userSnapshot.hasData)
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );

                                              final users =
                                                  userSnapshot.data!.docs;

                                              return ListView.builder(
                                                itemCount: users.length,
                                                itemBuilder: (context, index) {
                                                  final userData =
                                                      users[index].data()
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >;
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 8.0,
                                                        ),
                                                    child: WeeklyProgressWidget(
                                                      appId: widget.appId,
                                                      userId: userData['uid'],
                                                      userName:
                                                          userData['displayName'] ??
                                                          'User',
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  return WeeklyProgressWidget(
                                    appId: widget.appId,
                                    userId: currentUser.uid,
                                    userName: "My Weekly Goal",
                                  );
                                }
                              },
                            ),
                          const SizedBox(height: 32),

                          // Navigation Items
                          const Padding(
                            padding: EdgeInsets.only(left: 12, bottom: 12),
                            child: Text(
                              "MAIN MENU",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          _buildSidebarItem(
                            icon: Icons.dashboard_outlined,
                            selectedIcon: Icons.dashboard,
                            label: "Dashboard",
                            index: 0,
                          ),
                          const SizedBox(height: 8),
                          _buildSidebarItem(
                            icon: Icons.admin_panel_settings_outlined,
                            selectedIcon: Icons.admin_panel_settings,
                            label: "Admin Panel",
                            index: 1,
                          ),
                          const SizedBox(height: 8),
                          _buildSidebarItem(
                            icon: Icons.bar_chart_outlined,
                            selectedIcon: Icons.bar_chart,
                            label: "Analytics",
                            index: 2,
                          ),
                          // Role-based items
                          FutureBuilder<String>(
                            future: AuthService().getUserRole(),
                            builder: (context, snap) {
                              final isAdmin = snap.data == 'admin';
                              return Column(
                                children: [
                                  if (!isAdmin) ...[
                                    const SizedBox(height: 8),
                                    _buildSidebarItem(
                                      icon: Icons.assignment_outlined,
                                      selectedIcon: Icons.assignment,
                                      label: "Daily Report",
                                      index: 3,
                                    ),
                                  ],
                                  if (isAdmin) ...[
                                    const SizedBox(height: 8),
                                    _buildSidebarItem(
                                      icon: Icons.people_outline,
                                      selectedIcon: Icons.people,
                                      label: "Weekly Reports",
                                      index: 4,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // ── Pinned profile footer ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.displayName
                                          ?.isNotEmpty ==
                                      true
                                  ? FirebaseAuth
                                        .instance
                                        .currentUser!
                                        .displayName!
                                        .substring(0, 1)
                                        .toUpperCase()
                                  : "U",
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.displayName ??
                                      'Worker',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  FirebaseAuth.instance.currentUser?.email ??
                                      'No Email',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => AuthService().signOut(),
                            tooltip: "Logout",
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                EmployeePortal(appId: _appId),
                AdminLiveFeed(appId: _appId),
                AdminReports(appId: _appId),
                DailyReportPage(appId: _appId),
                AdminWeeklyReportsPage(appId: _appId),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Portal',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings),
                  label: 'Admin',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Reports',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment),
                  label: 'Daily',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[400] : Colors.grey[600]),
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
      ),
    );
  }
}

// --- VIEW 1: EMPLOYEE PORTAL ---
class EmployeePortal extends StatefulWidget {
  final String appId;
  const EmployeePortal({super.key, required this.appId});

  @override
  State<EmployeePortal> createState() => _EmployeePortalState();
}

class _EmployeePortalState extends State<EmployeePortal> {
  final TextEditingController _urlController = TextEditingController();
  bool _isClockedIn = false;
  String? _currentLogId;

  // Listen to the active log to detect changes from the extension (idle/stopped)
  StreamSubscription<DocumentSnapshot>? _logSubscription;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _logSubscription?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  void _listenToLog(String logId) {
    _logSubscription?.cancel();
    _logSubscription = FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('logs')
        .doc(logId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) return; // Add braces? No, return is fine

          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'];

          if (status == 'idle_stopped' || status == 'completed') {
            // Extension stopped the session
            setState(() {
              _isClockedIn = false;
              _currentLogId = null;
            });
            _logSubscription?.cancel();

            if (status == 'idle_stopped') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Session paused due to inactivity."),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            } else if (status == 'completed') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Session ended (Tab Closed)."),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        });
  }

  Future<void> _handleStartTracking() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    final user = FirebaseAuth.instance.currentUser;
    final logRef = FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('logs');

    final doc = await logRef.add({
      'userId': user?.uid,
      'userName': user?.displayName ?? 'Worker_${user?.uid.substring(0, 4)}',
      'site': url, // Storing the full URL now
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'status': 'active',
    });

    setState(() {
      _isClockedIn = true;
      _currentLogId = doc.id;
    });

    _listenToLog(doc.id);

    // Launch the URL
    final uri = Uri.parse(url);
    if (context.mounted) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        ); // externalApplication likely opens new tab/window
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Could not launch $url")));
      }
    }
  }

  Future<void> _handleStopTracking() async {
    if (_currentLogId == null) return;

    await FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('logs')
        .doc(_currentLogId)
        .update({
          'endTime': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

    setState(() {
      _isClockedIn = false;
      _currentLogId = null;
    });
    _logSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Stack(
      children: [
        if (MediaQuery.of(context).size.width <= 800)
          Positioned(
            top: 32,
            right: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.indigo[100],
                  child: Text(
                    user?.displayName?.isNotEmpty == true
                        ? user!.displayName!.substring(0, 1).toUpperCase()
                        : "U",
                    style: const TextStyle(fontSize: 24, color: Colors.indigo),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Hello, ${user?.displayName ?? 'Worker'}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tracking Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isClockedIn
                          ? Colors.red.withValues(alpha: 0.1)
                          : Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isClockedIn ? Icons.timer : Icons.public,
                      size: 64,
                      color: _isClockedIn
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _isClockedIn ? "Tracking Active" : "Start Tracking Session",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isClockedIn
                        ? "Your activity is being monitored."
                        : "Enter a URL to begin your work session safely.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (!_isClockedIn)
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: "Website URL to Track",
                        hintText: "e.g., github.com",
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _handleStartTracking(),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 8,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _urlController.text,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Don't close the tab or stay idle for > 5 mins!",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isClockedIn
                          ? _handleStopTracking
                          : _handleStartTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isClockedIn
                            ? Colors.red
                            : Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(
                        _isClockedIn ? "Stop Tracking" : "Launch & Track",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- VIEW 2: ADMIN LIVE FEED ---
class AdminLiveFeed extends StatelessWidget {
  final String appId;
  const AdminLiveFeed({super.key, required this.appId});

  void _showScreenshots(BuildContext context, String logId, String userName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 800,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Activity: $userName",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('artifacts')
                      .doc(appId)
                      .collection('public')
                      .doc('data')
                      .collection('logs')
                      .doc(logId)
                      .collection('screenshots')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text("No screenshots captured yet."),
                      );
                    }

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.5,
                          ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final String? imageUrl =
                            data['imageUrl']; // This is the data URL
                        final Timestamp? ts = data['timestamp'];

                        if (imageUrl == null) return const SizedBox.shrink();

                        // Decode base64
                        final base64String = imageUrl.split(',').last;
                        final Uint8List bytes = base64Decode(base64String);

                        return Card(
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Image.memory(
                                  bytes,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, s) =>
                                      const Icon(Icons.broken_image),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Text(
                                  ts != null
                                      ? DateFormat('h:mm a').format(ts.toDate())
                                      : 'Unknown',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please log in"));

    return Scaffold(
      appBar: AppBar(title: const Text("Live Team Status")),
      body: FutureBuilder<String>(
        future: AuthService().getUserRole(),
        builder: (context, roleSnapshot) {
          if (roleSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final isAdmin = roleSnapshot.data == 'admin';
          Query query = FirebaseFirestore.instance
              .collection('artifacts')
              .doc(appId)
              .collection('public')
              .doc('data')
              .collection('logs');

          if (!isAdmin) {
            query = query.where('userId', isEqualTo: user.uid);
          }

          // Only order by startTime if admin (avoids composite index for users)
          if (isAdmin) {
            query = query.orderBy('startTime', descending: true);
          }

          return StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Create a modifiable list
              final logs = List<QueryDocumentSnapshot>.from(
                snapshot.data!.docs,
              );

              // Client-side sort for non-admins
              if (!isAdmin) {
                logs.sort((a, b) {
                  final tA =
                      (a.data() as Map<String, dynamic>)['startTime']
                          as Timestamp?;
                  final tB =
                      (b.data() as Map<String, dynamic>)['startTime']
                          as Timestamp?;
                  if (tA == null || tB == null) return 0;
                  return tB.compareTo(tA); // Descending
                });
              }

              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        "No history available",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final bool isActive = log['endTime'] == null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        child: Icon(
                          isActive ? Icons.bolt : Icons.history,
                          color: isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                      title: Text(
                        log['userName'] ?? 'Unknown User',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        "${log['site']} • Started ${DateFormat('jm').format((log['startTime'] as Timestamp).toDate())}",
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.visibility_outlined,
                              color: Theme.of(context).primaryColor,
                            ),
                            tooltip: "View Screenshots",
                            onPressed: () => _showScreenshots(
                              context,
                              log.id,
                              log['userName'] ?? 'User',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isActive ? "ONLINE" : "Done",
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- VIEW 3: ADMIN REPORTS ---
class AdminReports extends StatefulWidget {
  final String appId;
  const AdminReports({super.key, required this.appId});

  @override
  State<AdminReports> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<AdminReports>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  static DateTime _startOfWeek([DateTime? from]) {
    final d = from ?? DateTime.now();
    final s = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(s.year, s.month, s.day);
  }

  /// Generate CSV text from weekly summary rows.
  String _buildCsv(List<Map<String, dynamic>> rows, String weekLabel) {
    final buf = StringBuffer();
    buf.writeln('Employee,Week,Hours Worked');
    for (final r in rows) {
      buf.writeln(
        '${r['userName']},$weekLabel,${(r['totalHours'] as double).toStringAsFixed(2)}',
      );
    }
    return buf.toString();
  }

  // ── This Week Tab ─────────────────────────────────────────────────────────
  Widget _buildThisWeek(User user, bool isAdmin) {
    final weekStart = _startOfWeek();

    Query query = FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('logs');

    if (isAdmin) {
      // Admin: safe to query all including date filter (single index)
      query = query
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
          )
          .orderBy('startTime', descending: true);
    } else {
      // Employee: query strictly by their userId to satisfy security rules.
      // We do date filtering in Dart to avoid composite index requirement.
      query = query.where('userId', isEqualTo: user.uid);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allLogs = snapshot.data!.docs;
        final List<QueryDocumentSnapshot> logs;

        if (isAdmin) {
          // Firestore already filtered by date and sorted by startTime
          logs = allLogs;
        } else {
          // Employee: manually filter by weekStart and sort
          logs =
              allLogs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final start = (data['startTime'] as Timestamp?)?.toDate();
                return start != null &&
                    (start.isAfter(weekStart) ||
                        start.isAtSameMomentAs(weekStart));
              }).toList()..sort((a, b) {
                final aStart =
                    (a.data() as Map<String, dynamic>)['startTime']
                        as Timestamp?;
                final bStart =
                    (b.data() as Map<String, dynamic>)['startTime']
                        as Timestamp?;
                if (aStart == null || bStart == null) return 0;
                return bStart.compareTo(aStart); // newest first
              });
        }

        Map<String, double> userTotals = {};
        for (var doc in logs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['startTime'] != null && data['endTime'] != null) {
            final start = (data['startTime'] as Timestamp).toDate();
            final end = (data['endTime'] as Timestamp).toDate();
            final hours = end.difference(start).inMinutes / 60.0;
            userTotals[data['userName'] ?? 'Unknown'] =
                (userTotals[data['userName'] ?? 'Unknown'] ?? 0) + hours;
          }
        }

        if (userTotals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No hours logged this week yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAdmin ? 'Team Hours — This Week' : 'My Hours — This Week',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Week of ${DateFormat('MMM d').format(weekStart)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 24),
                AnalyticsChart(logs: logs, isAdmin: isAdmin),
                const SizedBox(height: 24),
                DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).scaffoldBackgroundColor,
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Employee',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Hours This Week',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                  rows: userTotals.entries
                      .map(
                        (e) => DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.blue.withValues(
                                      alpha: 0.1,
                                    ),
                                    child: Text(
                                      e.key.substring(0, 1),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    e.key,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                '${e.value.toStringAsFixed(2)} hrs',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Past Weeks Tab ────────────────────────────────────────────────────────
  Widget _buildPastWeeks(User user, bool isAdmin) {
    Query query = FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('weekly_summaries');

    if (!isAdmin) query = query.where('userId', isEqualTo: user.uid);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawDocs = snapshot.data!.docs;
        if (rawDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No past weeks saved yet.\nThey appear automatically each Monday.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Sort client-side to avoid composite index requirement (userId + weekStart)
        final docs = List<QueryDocumentSnapshot>.from(rawDocs)
          ..sort((a, b) {
            final aStart =
                (a.data() as Map<String, dynamic>)['weekStart'] as Timestamp;
            final bStart =
                (b.data() as Map<String, dynamic>)['weekStart'] as Timestamp;
            return bStart.compareTo(aStart);
          });

        // Group by weekStart date string
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp ws = data['weekStart'];
          final Timestamp we = data['weekEnd'];
          final label =
              '${DateFormat('MMM d').format(ws.toDate())} – ${DateFormat('MMM d, yyyy').format(we.toDate())}';
          grouped.putIfAbsent(label, () => []).add(data);
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: grouped.entries.map((entry) {
            final weekLabel = entry.key;
            final rows = entry.value;
            final totalAll = rows.fold(
              0.0,
              (s, r) => s + (r['totalHours'] as num),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Week header row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Week: $weekLabel',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${isAdmin ? 'Team total' : 'My total'}: ${totalAll.toStringAsFixed(2)} hrs',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Download CSV button
                      OutlinedButton.icon(
                        onPressed: () {
                          final csv = _buildCsv(rows, weekLabel);
                          _showCsvDialog(
                            csv,
                            'hours_${weekLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.csv',
                          );
                        },
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('CSV'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  // Employee rows
                  ...rows.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            child: Text(
                              (r['userName'] as String? ?? '?')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              r['userName'] ?? 'Unknown',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${(r['totalHours'] as num).toStringAsFixed(2)} hrs',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
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
                  // Direct launch often works better on web without canLaunchUrl check
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please log in'));

    return FutureBuilder<String>(
      future: AuthService().getUserRole(),
      builder: (context, roleSnapshot) {
        final isAdmin = roleSnapshot.data == 'admin';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Analytics'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_today), text: 'This Week'),
                Tab(icon: Icon(Icons.history), text: 'Past Weeks'),
              ],
            ),
          ),
          body: roleSnapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildThisWeek(user, isAdmin),
                    _buildPastWeeks(user, isAdmin),
                  ],
                ),
        );
      },
    );
  }
}

// --- WIDGET: WEEKLY PROGRESS ---
class WeeklyProgressWidget extends StatefulWidget {
  final String appId;
  final String userId;
  final String? userName; // Optional name for Admin View

  const WeeklyProgressWidget({
    super.key,
    required this.appId,
    required this.userId,
    this.userName,
  });

  @override
  State<WeeklyProgressWidget> createState() => _WeeklyProgressWidgetState();
}

class _WeeklyProgressWidgetState extends State<WeeklyProgressWidget> {
  Timer? _timer;

  // Helper — accepts optional date so we can compute previous week start too
  DateTime _getStartOfWeek([DateTime? from]) {
    final d = from ?? DateTime.now();
    final startOfWeek = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  }

  /// Auto-saves the PREVIOUS week's total hours to weekly_summaries if not
  /// already stored. Fire-and-forget from initState.
  Future<void> _maybeSavePreviousWeek() async {
    final now = DateTime.now();
    final thisWeekStart = _getStartOfWeek(now);
    final prevWeekStart = _getStartOfWeek(
      thisWeekStart.subtract(const Duration(days: 1)),
    );
    final prevWeekEnd = thisWeekStart.subtract(const Duration(seconds: 1));

    final docId =
        '${prevWeekStart.toIso8601String().split('T').first}_${widget.userId}';
    final coll = FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('weekly_summaries');

    final existing = await coll.doc(docId).get();
    if (existing.exists) return;

    final logsSnap = await FirebaseFirestore.instance
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('logs')
        .where('userId', isEqualTo: widget.userId)
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(prevWeekStart),
        )
        .where(
          'startTime',
          isLessThanOrEqualTo: Timestamp.fromDate(prevWeekEnd),
        )
        .get();

    double totalHours = 0;
    String resolvedName = widget.userName ?? '';
    for (var doc in logsSnap.docs) {
      final data = doc.data();
      final Timestamp? st = data['startTime'];
      final Timestamp? et = data['endTime'];
      if (st == null || et == null) continue;
      totalHours += et.toDate().difference(st.toDate()).inMinutes / 60.0;
      if (resolvedName.isEmpty) resolvedName = data['userName'] ?? '';
    }

    await coll.doc(docId).set({
      'userId': widget.userId,
      'userName': resolvedName,
      'weekStart': Timestamp.fromDate(prevWeekStart),
      'weekEnd': Timestamp.fromDate(prevWeekEnd),
      'totalHours': totalHours,
    });
  }

  @override
  void initState() {
    super.initState();
    _maybeSavePreviousWeek();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Stream logs for this user
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artifacts')
          .doc(widget.appId)
          .collection('public')
          .doc('data')
          .collection('logs')
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        double totalHours = 0;
        final startOfWeek = _getStartOfWeek();
        final now = DateTime.now();

        // 2. Filter & Calculate Duration
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp? startTs = data['startTime'];
          if (startTs == null) continue;

          final DateTime startTime = startTs.toDate();

          // Filter: Must be after start of this week
          if (startTime.isBefore(startOfWeek)) continue;

          final Timestamp? endTs = data['endTime'];

          if (endTs != null) {
            // Completed session
            final DateTime endTime = endTs.toDate();
            totalHours += endTime.difference(startTime).inMinutes / 60.0;
          } else {
            // Active session (calculate up to NOW)
            totalHours += now.difference(startTime).inMinutes / 60.0;
          }
        }

        // 3. Determine Color & Progress
        final double targetMin = 15.0;
        final double targetMax = 20.0;

        Color progressColor;
        if (totalHours >= targetMax) {
          progressColor = Colors.green;
        } else if (totalHours >= targetMin) {
          progressColor = Colors.amber;
        } else {
          progressColor = Theme.of(context).primaryColor;
        }

        // Cap progress at 1.0 for the bar (or let it go full if > 20)
        double progressValue = (totalHours / targetMax).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    // Prevent overflow if name is long
                    child: Text(
                      widget.userName ?? "Weekly Goal",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${totalHours.toStringAsFixed(1)} / 20 hrs",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: Theme.of(
                    context,
                  ).dividerColor.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                totalHours >= targetMax
                    ? "Goal Reached! 🚀"
                    : (totalHours >= targetMin
                          ? "Almost there! Keep it up."
                          : "Keep going!"),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- WIDGET: ANALYTICS CHART ---
class AnalyticsChart extends StatelessWidget {
  final List<QueryDocumentSnapshot> logs;
  final bool isAdmin;

  const AnalyticsChart({super.key, required this.logs, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    // 1. Process Data
    Map<String, double> chartData = {};

    if (isAdmin) {
      // Admin: Group by User
      for (var doc in logs) {
        final data = doc.data() as Map<String, dynamic>;
        final userName = data['userName'] ?? 'Unknown';
        double hours = 0;

        if (data['startTime'] != null && data['endTime'] != null) {
          final start = (data['startTime'] as Timestamp).toDate();
          final end = (data['endTime'] as Timestamp).toDate();
          hours = end.difference(start).inMinutes / 60.0;
        }

        chartData[userName] = (chartData[userName] ?? 0) + hours;
      }
    } else {
      // Employee: Group by Day (Last 7 Days)
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        // Simple day key: "Mon", "Tue" etc.
        final dayName = DateFormat('E').format(day);
        chartData[dayName] = 0.0; // Initialize with 0.0
      }

      for (var doc in logs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['startTime'] != null && data['endTime'] != null) {
          final start = (data['startTime'] as Timestamp).toDate();
          final end = (data['endTime'] as Timestamp).toDate();

          // Only include if within last 7 days
          if (now.difference(start).inDays <= 7) {
            final dayName = DateFormat('E').format(start);
            // Verify this day is in our map (it should be)
            if (chartData.containsKey(dayName)) {
              double hours = end.difference(start).inMinutes / 60.0;
              chartData[dayName] = (chartData[dayName] ?? 0) + hours;
            }
          }
        }
      }
    }

    final sortedKeys = chartData.keys.toList(); // For reliable index mapping
    // Calculate maxY for the chart
    final double maxY = chartData.values.isEmpty
        ? 10.0
        : (chartData.values.reduce((a, b) => a > b ? a : b) * 1.2);

    if (sortedKeys.isEmpty) return const SizedBox();

    return AspectRatio(
      aspectRatio: 2.5,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Text(
              isAdmin ? "Team Comparison (Total Hours)" : "My Weekly Activity",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY, // dynamic max Y
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final key = sortedKeys[group.x.toInt()];
                        return BarTooltipItem(
                          '$key\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: '${rod.toY.toStringAsFixed(1)} hrs',
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value.toInt() >= sortedKeys.length)
                            return const SizedBox();
                          final key = sortedKeys[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              // Abbreviate name if Admin
                              isAdmin && key.length > 4
                                  ? "${key.substring(0, 3)}."
                                  : key,
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            "${value.toInt()}h",
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedKeys.asMap().entries.map((entry) {
                    final index = entry.key;
                    final key = entry.value;
                    final value = chartData[key] ?? 0;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: value >= 20
                              ? Colors.green
                              : (value >= 15
                                    ? Colors.amber
                                    : Theme.of(context).primaryColor),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 20, // Target line visual (reference)
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

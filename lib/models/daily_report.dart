import 'package:cloud_firestore/cloud_firestore.dart';

class ViralMailerEntry {
  String name;
  String siteName;
  int sentTo;
  int clicks;
  double ctr;
  int emailsClicked;
  String frequency;

  ViralMailerEntry({
    required this.name,
    this.siteName = '',
    this.sentTo = 0,
    this.clicks = 0,
    this.ctr = 0.0,
    this.emailsClicked = 0,
    this.frequency = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'siteName': siteName,
      'sentTo': sentTo,
      'clicks': clicks,
      'ctr': ctr,
      'emailsClicked': emailsClicked,
      'frequency': frequency,
    };
  }

  factory ViralMailerEntry.fromMap(Map<String, dynamic> map) {
    return ViralMailerEntry(
      name: map['name'] ?? '',
      siteName: map['siteName'] ?? '',
      sentTo: map['sentTo'] ?? 0,
      clicks: map['clicks'] ?? 0,
      ctr: (map['ctr'] ?? 0).toDouble(),
      emailsClicked: map['emailsClicked'] ?? 0,
      frequency: map['frequency'] ?? '',
    );
  }
}

class TrafficExchangeEntry {
  String name;
  String url;
  int hits;
  int surfCount;

  TrafficExchangeEntry({
    required this.name,
    this.url = '',
    this.hits = 0,
    this.surfCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'url': url, 'hits': hits, 'surfCount': surfCount};
  }

  factory TrafficExchangeEntry.fromMap(Map<String, dynamic> map) {
    return TrafficExchangeEntry(
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      hits: map['hits'] ?? 0,
      surfCount: map['surfCount'] ?? 0,
    );
  }
}

class SocialMediaEntry {
  String name;
  String postLink;

  SocialMediaEntry({required this.name, this.postLink = ''});

  Map<String, dynamic> toMap() {
    return {'name': name, 'postLink': postLink};
  }

  factory SocialMediaEntry.fromMap(Map<String, dynamic> map) {
    return SocialMediaEntry(
      name: map['name'] ?? '',
      postLink: map['postLink'] ?? '',
    );
  }
}

class TrackingLinkEntry {
  String url;
  int totalHits;
  String top3Countries;
  String top3Sites;

  TrackingLinkEntry({
    required this.url,
    this.totalHits = 0,
    this.top3Countries = '',
    this.top3Sites = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'totalHits': totalHits,
      'top3Countries': top3Countries,
      'top3Sites': top3Sites,
    };
  }

  factory TrackingLinkEntry.fromMap(Map<String, dynamic> map) {
    return TrackingLinkEntry(
      url: map['url'] ?? '',
      totalHits: map['totalHits'] ?? 0,
      top3Countries: map['top3Countries'] ?? '',
      top3Sites: map['top3Sites'] ?? '',
    );
  }
}

class WeeklyMailerEntry {
  String siteName;
  int mailedThisWeek;
  int newMembersThisWeek;
  int subscribedMembers;

  WeeklyMailerEntry({
    this.siteName = '',
    this.mailedThisWeek = 0,
    this.newMembersThisWeek = 0,
    this.subscribedMembers = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'siteName': siteName,
      'mailedThisWeek': mailedThisWeek,
      'newMembersThisWeek': newMembersThisWeek,
      'subscribedMembers': subscribedMembers,
    };
  }

  factory WeeklyMailerEntry.fromMap(Map<String, dynamic> map) {
    return WeeklyMailerEntry(
      siteName: map['siteName'] ?? '',
      mailedThisWeek: map['mailedThisWeek'] ?? 0,
      newMembersThisWeek: map['newMembersThisWeek'] ?? 0,
      subscribedMembers: map['subscribedMembers'] ?? 0,
    );
  }
}

class DailyReport {
  String id;
  String userId;
  String userName;
  DateTime date;
  String otherTasks;
  bool isWeeklySubmission;

  List<ViralMailerEntry> viralMailers;
  List<TrafficExchangeEntry> trafficExchanges;
  List<SocialMediaEntry> socialMedia;
  List<TrackingLinkEntry> trackingLinks;
  List<WeeklyMailerEntry> weeklyMailers;

  // Part 3 – Weekly Review
  List<String> keyTasksCompleted;
  List<String> goalsForTheWeek;
  List<String> achievementsWins;
  List<String> challengesObstacles;
  List<String> solutionsActionsTaken;
  List<String> skillsLearning;
  List<String> performanceRating;
  List<String> goalsNextWeek;
  List<String> additionalNotes;

  DailyReport({
    required this.id,
    required this.userId,
    required this.userName,
    required this.date,
    this.otherTasks = '',
    this.isWeeklySubmission = false,
    required this.viralMailers,
    required this.trafficExchanges,
    required this.socialMedia,
    required this.trackingLinks,
    this.weeklyMailers = const [],
    this.keyTasksCompleted = const [''],
    this.goalsForTheWeek = const [''],
    this.achievementsWins = const [''],
    this.challengesObstacles = const [''],
    this.solutionsActionsTaken = const [''],
    this.skillsLearning = const [''],
    this.performanceRating = const [''],
    this.goalsNextWeek = const [''],
    this.additionalNotes = const [''],
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'date': Timestamp.fromDate(date),
      'otherTasks': otherTasks,
      'isWeeklySubmission': isWeeklySubmission,
      'viralMailers': viralMailers.map((e) => e.toMap()).toList(),
      'trafficExchanges': trafficExchanges.map((e) => e.toMap()).toList(),
      'socialMedia': socialMedia.map((e) => e.toMap()).toList(),
      'trackingLinks': trackingLinks.map((e) => e.toMap()).toList(),
      'weeklyMailers': weeklyMailers.map((e) => e.toMap()).toList(),
      'keyTasksCompleted': keyTasksCompleted,
      'goalsForTheWeek': goalsForTheWeek,
      'achievementsWins': achievementsWins,
      'challengesObstacles': challengesObstacles,
      'solutionsActionsTaken': solutionsActionsTaken,
      'skillsLearning': skillsLearning,
      'performanceRating': performanceRating,
      'goalsNextWeek': goalsNextWeek,
      'additionalNotes': additionalNotes,
    };
  }

  factory DailyReport.fromMap(String id, Map<String, dynamic> map) {
    return DailyReport(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      otherTasks: map['otherTasks'] ?? '',
      isWeeklySubmission: map['isWeeklySubmission'] ?? false,
      viralMailers:
          (map['viralMailers'] as List<dynamic>?)
              ?.map((e) => ViralMailerEntry.fromMap(e))
              .toList() ??
          [],
      trafficExchanges:
          (map['trafficExchanges'] as List<dynamic>?)
              ?.map((e) => TrafficExchangeEntry.fromMap(e))
              .toList() ??
          [],
      socialMedia:
          (map['socialMedia'] as List<dynamic>?)
              ?.map((e) => SocialMediaEntry.fromMap(e))
              .toList() ??
          [],
      trackingLinks:
          (map['trackingLinks'] as List<dynamic>?)
              ?.map((e) => TrackingLinkEntry.fromMap(e))
              .toList() ??
          [],
      weeklyMailers:
          (map['weeklyMailers'] as List<dynamic>?)
              ?.map((e) => WeeklyMailerEntry.fromMap(e))
              .toList() ??
          [],
      keyTasksCompleted: List<String>.from(map['keyTasksCompleted'] ?? ['']),
      goalsForTheWeek: List<String>.from(map['goalsForTheWeek'] ?? ['']),
      achievementsWins: List<String>.from(map['achievementsWins'] ?? ['']),
      challengesObstacles: List<String>.from(
        map['challengesObstacles'] ?? [''],
      ),
      solutionsActionsTaken: List<String>.from(
        map['solutionsActionsTaken'] ?? [''],
      ),
      skillsLearning: List<String>.from(map['skillsLearning'] ?? ['']),
      performanceRating: List<String>.from(map['performanceRating'] ?? ['']),
      goalsNextWeek: List<String>.from(map['goalsNextWeek'] ?? ['']),
      additionalNotes: List<String>.from(map['additionalNotes'] ?? ['']),
    );
  }

  // Factory for empty initial report
  factory DailyReport.empty(String userId, String userName, DateTime date) {
    return DailyReport(
      id: '',
      userId: userId,
      userName: userName,
      date: date,
      otherTasks: '',
      viralMailers: [
        ViralMailerEntry(name: 'Viral Mailer 1'),
        ViralMailerEntry(name: 'Viral Mailer 2'),
        ViralMailerEntry(name: 'Viral Mailer 3'),
        ViralMailerEntry(name: 'Viral Mailer 4'),
        ViralMailerEntry(name: 'Viral Mailer 5'),
      ],
      trafficExchanges: [
        TrafficExchangeEntry(name: 'Traffic Exchange 1 (Happypig country)'),
        TrafficExchangeEntry(name: 'Traffic Exchange 2 (Traffic ad bar)'),
        TrafficExchangeEntry(name: 'Traffic Exchange 3 (Leadsleap)'),
        TrafficExchangeEntry(name: 'Traffic Exchange 4 (Elite traffic)'),
        TrafficExchangeEntry(name: 'Traffic Exchange 5 (Taxi cab hits)'),
        TrafficExchangeEntry(name: 'Traffic Exchange 6 (Lagos traffic)'),
        TrafficExchangeEntry(name: 'Traffic Exchange 8 (Happy pig country)'),
      ],
      socialMedia: [
        SocialMediaEntry(name: 'Social Media 1'),
        SocialMediaEntry(name: 'Social Media 2'),
        SocialMediaEntry(name: 'Social Media 3'),
      ],
      trackingLinks: [
        TrackingLinkEntry(url: 'Tracking Link 1'),
        TrackingLinkEntry(url: 'Tracking Link 2'),
        TrackingLinkEntry(url: 'Tracking Link 3'),
      ],
      weeklyMailers: [WeeklyMailerEntry(siteName: 'Launch Beacon')],
    );
  }
}

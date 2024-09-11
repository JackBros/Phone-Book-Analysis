import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Call Log Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => WeekPage(),
      },
    );
  }
}

class DailyConversation {
  String contactName;
  String phoneNumber;
  int totalCalls;
  Duration totalDuration;
  double averageDuration;

  DailyConversation({
    required this.contactName,
    required this.phoneNumber,
    required this.totalCalls,
    required this.totalDuration,
    required this.averageDuration,
  });
}

class WeekPage extends StatefulWidget {
  @override
  _WeekPageState createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  List<DailyConversation> _weeklyConversations = [];

  @override
  void initState() {
    super.initState();
    _getWeeklyConversations();
  }

  Future<void> _getWeeklyConversations() async {
    DateTime now = DateTime.now();
    DateTime lastWeek = now.subtract(Duration(days: 7));

    Iterable<CallLogEntry> callLogs = await CallLog.query(
      dateFrom: lastWeek.millisecondsSinceEpoch,
      dateTo: now.millisecondsSinceEpoch,
    );

    print("Call logs retrieved: ${callLogs.length}");

    Map<String, DailyConversation> conversationMap = {};

    callLogs.forEach((callLog) {
      if (callLog.callType == CallType.outgoing || callLog.callType == CallType.incoming) {
        String phoneNumber = callLog.number ?? "";
        String contactName = callLog.name ?? phoneNumber;

        if (!conversationMap.containsKey(contactName)) {
          conversationMap[contactName] = DailyConversation(
            contactName: contactName,
            phoneNumber: phoneNumber,
            totalCalls: 0,
            totalDuration: Duration.zero,
            averageDuration: 0,
          );
        }

        DailyConversation conversation = conversationMap[contactName]!;
        conversation.totalCalls++;
        conversation.totalDuration += Duration(seconds: callLog.duration ?? 0);
      }
    });

    conversationMap.values.forEach((conversation) {
      conversation.averageDuration = conversation.totalDuration.inSeconds / conversation.totalCalls;
    });

    setState(() {
      _weeklyConversations = conversationMap.values.toList();
    });

    print("Weekly conversations retrieved: ${_weeklyConversations.length}");
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly'),
      ),
      body: ListView.builder(
        itemCount: _weeklyConversations.length,
        itemBuilder: (context, index) {
          DailyConversation conversation = _weeklyConversations[index];
          return ListTile(
            title: Text(conversation.contactName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone Number: ${conversation.phoneNumber}'),
                Text('Total Calls: ${conversation.totalCalls}'),
                Text('Total Duration: ${_formatDuration(conversation.totalDuration)}'),
                Text('Average Duration: ${conversation.averageDuration.toStringAsFixed(2)} seconds'),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds.remainder(60);
    return '$minutes minutes $seconds seconds';
  }
}

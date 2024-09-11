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
        '/': (context) => ThreeMonthPage(),
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

class ThreeMonthPage extends StatefulWidget {
  @override
  _ThreeMonthPageState createState() => _ThreeMonthPageState();
}

class _ThreeMonthPageState extends State<ThreeMonthPage> {
  List<DailyConversation> _threeMonthConversations = [];

  @override
  void initState() {
    super.initState();
    _getThreeMonthConversations();
  }

  Future<void> _getThreeMonthConversations() async {
    DateTime now = DateTime.now();
    DateTime threeMonthsAgo = now.subtract(Duration(days: 90));

    Iterable<CallLogEntry> callLogs = await CallLog.query(
      dateFrom: threeMonthsAgo.millisecondsSinceEpoch,
      dateTo: now.millisecondsSinceEpoch,
    );

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
      _threeMonthConversations = conversationMap.values.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Three Months'),
      ),
      body: ListView.builder(
        itemCount: _threeMonthConversations.length,
        itemBuilder: (context, index) {
          DailyConversation conversation = _threeMonthConversations[index];
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

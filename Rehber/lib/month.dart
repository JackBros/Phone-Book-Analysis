import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Contacts Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => MonthPage(), // Ana sayfa olarak direkt aylık raporu göster
      },
    );
  }
}

class DailyConversation {
  String contactName;
  String phoneNumber;
  DateTime dateTime;
  int totalCalls;
  Duration totalDuration;
  double averageDuration;

  DailyConversation({
    required this.contactName,
    required this.phoneNumber,
    required this.dateTime,
    required this.totalCalls,
    required this.totalDuration,
    required this.averageDuration,
  });
}

class MonthPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Monthly'),
      ),
      body: FutureBuilder<List<DailyConversation>>(
        future: _getMonthlyConversations(), // Aylık konuşmaları al
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          } else {
            List<DailyConversation> monthlyConversations = snapshot.data!;
            return ListView.builder(
              itemCount: monthlyConversations.length,
              itemBuilder: (context, index) {
                DailyConversation conversation = monthlyConversations[index];
                return ListTile(
                  title: Text(conversation.contactName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Phone Number: ${conversation.phoneNumber}'),
                      Text('Total Phone Calls: ${conversation.totalCalls}'),
                      Text('Total Phone Call Duration: ${_formatDuration(conversation.totalDuration)}'),
                      Text('Average Phone Call Duration: ${conversation.averageDuration.toStringAsFixed(2)} second'),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<List<DailyConversation>> _getMonthlyConversations() async {
    DateTime now = DateTime.now();
    DateTime lastMonth = DateTime(now.year, now.month - 1, now.day); // Geçen ayın başlangıcı

    Iterable<CallLogEntry> callLogs = await CallLog.query(
      dateFrom: lastMonth.millisecondsSinceEpoch, // Geçen aydan itibaren olan arama kayıtları
      dateTo: now.millisecondsSinceEpoch, // Şu anki zamana kadar olan arama kayıtları
    );

    Map<String, DailyConversation> conversationMap = {};

    callLogs.forEach((callLog) {
      if (callLog.callType == CallType.outgoing || callLog.callType == CallType.incoming) {
        String phoneNumber = callLog.number ?? "";
        String contactName = callLog.name ?? phoneNumber; // Eğer kişi adı yoksa telefon numarasını kullan

        if (!conversationMap.containsKey(contactName)) {
          conversationMap[contactName] = DailyConversation(
            contactName: contactName,
            phoneNumber: phoneNumber,
            dateTime: callLog.timestamp != null ? DateTime.fromMillisecondsSinceEpoch(callLog.timestamp!) : DateTime.now(),
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

    // Ortalama konuşma süresini hesapla
    conversationMap.values.forEach((conversation) {
      conversation.averageDuration = conversation.totalDuration.inSeconds / conversation.totalCalls;
    });

    return conversationMap.values.toList();
  }

  String _formatDuration(Duration duration) {
    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds.remainder(60);
    return '$minutes minute $seconds second';
  }
}

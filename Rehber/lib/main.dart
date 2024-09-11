import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:call_log/call_log.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:rehber_uygulamasi/delete.dart';
import 'package:rehber_uygulamasi/month.dart';
import 'package:rehber_uygulamasi/privacy_policy.dart';
import 'package:rehber_uygulamasi/three_month.dart';
import 'package:rehber_uygulamasi/week.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Contacts',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => MyHomePage(),
        '/week': (context) => WeekPage(),
        '/month': (context) => MonthPage(),
        '/three_month': (context) => ThreeMonthPage(),
        '/delete': (context) => DeletePage(),
        '/privacy_policy': (context) => PrivacyPolicyPage(),
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

  DailyConversation({
    required this.contactName,
    required this.phoneNumber,
    required this.dateTime,
    required this.totalCalls,
    required this.totalDuration,
  });

  double get averageDuration {
    return totalDuration.inSeconds / totalCalls;
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Contact> _contacts = [];
  List<DailyConversation> _dailyConversations = [];
  bool _sortByCalls = true;
  String _recipientEmail = "";

  @override
  void initState() {
    super.initState();
    _getContacts();
  }

  Future<void> _getContacts() async {
    if (await Permission.contacts.request().isGranted) {
      Iterable<Contact> contacts = await ContactsService.getContacts();
      setState(() {
        _contacts = contacts.toList();
      });
      _getDailyConversations();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Access Permission Required'),
          content: Text('You must grant access to the phone book (data is not backed up, only you can see it).'),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  Future<Iterable<CallLogEntry>> _getCallLogs() async {
    if (await Permission.phone.request().isGranted) {
      return await CallLog.get();
    } else {
      return [];
    }
  }

  void _getDailyConversations() async {
    List<DailyConversation> dailyConversations = [];
    DateTime now = DateTime.now();

    _getCallLogs().then((callLogs) {
      for (Contact contact in _contacts) {
        int totalCalls = 0;
        Duration totalDuration = Duration.zero;
        callLogs.forEach((callLog) {
          if (callLog.callType == CallType.outgoing ||
              callLog.callType == CallType.incoming) {
            String phoneNumber = callLog.number ?? "";
            String contactName = _getContactName(phoneNumber);
            if (contact.displayName == contactName &&
                callLog.timestamp != null &&
                callLog.duration != null) {
              DateTime callDateTime = DateTime.fromMillisecondsSinceEpoch(callLog.timestamp!);
              if (callDateTime.day == now.day &&
                  callDateTime.month == now.month &&
                  callDateTime.year == now.year) {
                totalCalls++;
                totalDuration += Duration(seconds: callLog.duration!);
              }
            }
          }
        });
        if (totalCalls > 0) {
          dailyConversations.add(DailyConversation(
            contactName: contact.displayName ?? "",
            phoneNumber: contact.phones?.first.value ?? "",
            dateTime: now,
            totalCalls: totalCalls,
            totalDuration: totalDuration,
          ));
        }
      }
      setState(() {
        _dailyConversations = dailyConversations;
      });
    });
  }

  String _getContactName(String phoneNumber) {
    for (Contact contact in _contacts) {
      for (Item phone in contact.phones ?? []) {
        if (phone.value == phoneNumber) {
          return contact.displayName ?? "";
        }
      }
    }
    return "";
  }

  Future<void> _sendEmail(String recipientEmail, List<DailyConversation> conversations, String period) async {
    String emailBody = _buildEmailBody(conversations, period);

    String username = 'phonebookanalysis@gmail.com';
    String password = 'dbrb schn qjbb lafx';

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address(username, 'Your Name')
      ..recipients.add(recipientEmail)
      ..subject = 'Conversations Report - $period'
      ..text = emailBody;

    try {
      final sendReport = await send(message, smtpServer);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email sent: ' + sendReport.toString())),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email not sent. \n' + e.toString())),
      );
    }
  }

  String _buildEmailBody(List<DailyConversation> conversations, String period) {
    StringBuffer buffer = StringBuffer();

    buffer.writeln('Report Period: $period');
    buffer.writeln('----------------------');

    for (DailyConversation conversation in conversations) {
      buffer.writeln('Contact Name: ${conversation.contactName}');
      buffer.writeln('Phone Number: ${conversation.phoneNumber}');
      buffer.writeln('Total Calls: ${conversation.totalCalls}');
      buffer.writeln(
          'Total Duration: ${conversation.totalDuration.inMinutes} minutes ${conversation.totalDuration.inSeconds.remainder(60)} seconds');
      buffer.writeln(
          'Average Duration: ${conversation.averageDuration.toStringAsFixed(2)} seconds');
      buffer.writeln('----------------------');
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'week':
                  Navigator.pushNamed(context, '/week');
                  break;
                case 'month':
                  Navigator.pushNamed(context, '/month');
                  break;
                case 'three_month':
                  Navigator.pushNamed(context, '/three_month');
                  break;
                case 'delete':
                  Navigator.pushNamed(context, '/delete');
                  break;
                case 'privacy_policy':
                  Navigator.pushNamed(context, '/privacy_policy');
                  break;
                case 'send_email':
                  _showEmailOptionsDialog();
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return {
                'week': 'Week',
                'month': 'Month',
                'three_month': 'Three Month',
                'delete': 'Delete',
                'send_email': 'Send data to email',
                'privacy_policy': 'Privacy Policy',
              }.entries.map((entry) {
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _sortByCalls = true;
                    });
                  },
                  child: Text('Sort by Number of Calls'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _sortByCalls = false;
                    });
                  },
                  child: Text('Sort by Total Time'),
                ),
              ),
            ],
          ),
          Expanded(
            child: _buildContactList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactList() {
    List<DailyConversation> sortedConversations = List.from(_dailyConversations);

    sortedConversations.sort((a, b) {
      if (_sortByCalls) {
        return b.totalCalls.compareTo(a.totalCalls);
      } else {
        return b.totalDuration.compareTo(a.totalDuration);
      }
    });

    return ListView.builder(
      itemCount: sortedConversations.length,
      itemBuilder: (context, index) {
        DailyConversation conversation = sortedConversations[index];
        return ListTile(
          title: Text(conversation.contactName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phone Number: ${conversation.phoneNumber}'),
              Text('Total Phone Calls: ${conversation.totalCalls}'),
              Text(
                  'Total Phone Call Duration: ${conversation.totalDuration.inMinutes} minute ${conversation.totalDuration.inSeconds.remainder(60)} second'),
              Text(
                  'Average Phone Call Duration: ${conversation.averageDuration.toStringAsFixed(2)} second'),
            ],
          ),
          trailing: Text(conversation.dateTime.toString()),
        );
      },
    );
  }

  void _showEmailOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String email = '';
        String selectedOption = 'daily';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Send an Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      email = value;
                    },
                    decoration: InputDecoration(hintText: "Enter Email Address"),
                  ),
                  DropdownButton<String>(
                    value: selectedOption,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedOption = newValue!;
                      });
                    },
                    items: <String>['daily', 'weekly', 'monthly', 'three months']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Send'),
                  onPressed: () {
                    _getAndSendConversations(email, selectedOption);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _getAndSendConversations(String email, String option) async {
    DateTime now = DateTime.now();
    DateTime startDate;
    List<DailyConversation> conversations = [];

    switch (option) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        conversations = _dailyConversations;
        break;
      case 'weekly':
        startDate = now.subtract(Duration(days: 7));
        conversations = await _getConversationsFrom(startDate);
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month - 1, now.day);
        conversations = await _getConversationsFrom(startDate);
        break;
      case 'three months':
        startDate = DateTime(now.year, now.month - 3, now.day);
        conversations = await _getConversationsFrom(startDate);
        break;
    }

    _sendEmail(email, conversations, option);
  }

  Future<List<DailyConversation>> _getConversationsFrom(DateTime startDate) async {
    List<DailyConversation> conversations = [];
    DateTime now = DateTime.now();
    Iterable<CallLogEntry> callLogs = await _getCallLogs();

    for (Contact contact in _contacts) {
      int totalCalls = 0;
      Duration totalDuration = Duration.zero;

      for (CallLogEntry callLog in callLogs) {
        if (callLog.callType == CallType.outgoing || callLog.callType == CallType.incoming) {
          String phoneNumber = callLog.number ?? "";
          String contactName = _getContactName(phoneNumber);
          if (contact.displayName == contactName && callLog.timestamp != null && callLog.duration != null) {
            DateTime callDateTime = DateTime.fromMillisecondsSinceEpoch(callLog.timestamp!);
            if (callDateTime.isAfter(startDate) && callDateTime.isBefore(now)) {
              totalCalls++;
              totalDuration += Duration(seconds: callLog.duration!);
            }
          }
        }
      }

      if (totalCalls > 0) {
        conversations.add(DailyConversation(
          contactName: contact.displayName ?? "",
          phoneNumber: contact.phones?.first.value ?? "",
          dateTime: now,
          totalCalls: totalCalls,
          totalDuration: totalDuration,
        ));
      }
    }

    return conversations;
  }
}
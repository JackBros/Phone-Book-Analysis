import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:call_log/call_log.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delete Contacts',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DeletePage(),
    );
  }
}

class DeletePage extends StatefulWidget {
  @override
  _DeletePageState createState() => _DeletePageState();
}

class _DeletePageState extends State<DeletePage> {
  List<Contact> _contacts = [];
  List<Contact> _inactiveContacts = [];
  List<Contact> _leastCalledContacts = [];

  @override
  void initState() {
    super.initState();
    _getPermissions();
  }

  // İzinleri almak için metod
  Future<void> _getPermissions() async {
    bool contactsGranted = await Permission.contacts.request().isGranted;
    bool callLogsGranted = await Permission.phone.request().isGranted; // `Permission.phone` call logları da kapsar

    if (contactsGranted && callLogsGranted) {
      await _getContacts();
    } else {
      print('Access to contacts or call logs was not granted.');
    }
  }

  // Rehberi almak için izin iste ve rehberdeki kişileri getir
  Future<void> _getContacts() async {
    Iterable<Contact> contacts = await ContactsService.getContacts();
    setState(() {
      _contacts = contacts.toList();
    });
    await _fetchContactsData();  // Kişiler yüklendikten sonra verileri getir
  }

  // Son 6 ayda konuşulmayan ve en az konuşulan kişilerin listesini al
  Future<void> _fetchContactsData() async {
    DateTime sixMonthsAgo = DateTime.now().subtract(Duration(days: 180));
    Iterable<CallLogEntry> callLogs = await CallLog.query(
      dateFrom: sixMonthsAgo.millisecondsSinceEpoch,
    );

    setState(() {
      _inactiveContacts = _getInactiveContacts(_contacts, callLogs);
      _leastCalledContacts = _getLeastCalledContacts(_contacts, callLogs);
    });
  }

  // Son 6 ayda hiç konuşulmayan kişilerin listesini al
  List<Contact> _getInactiveContacts(List<Contact> contacts, Iterable<CallLogEntry> callLogs) {
    DateTime sixMonthsAgo = DateTime.now().subtract(Duration(days: 180));
    List<Contact> inactiveContacts = [];

    for (Contact contact in contacts) {
      bool isActive = false;
      for (CallLogEntry callLog in callLogs) {
        if (callLog.number == contact.phones?.first.value &&
            callLog.timestamp != null &&
            callLog.timestamp! >= sixMonthsAgo.millisecondsSinceEpoch) {
          isActive = true;
          break;
        }
      }
      if (!isActive) {
        inactiveContacts.add(contact);
      }
    }

    return inactiveContacts;
  }

  // En az konuşulan kişilerin listesini al
  List<Contact> _getLeastCalledContacts(List<Contact> contacts, Iterable<CallLogEntry> callLogs) {
    Map<String, int> callCounts = {};

    for (CallLogEntry callLog in callLogs) {
      String? number = callLog.number;
      if (number != null) {
        if (callCounts.containsKey(number)) {
          callCounts[number] = callCounts[number]! + 1;
        } else {
          callCounts[number] = 1;
        }
      }
    }

    // Call counts sorted by the number of calls in ascending order
    List<String> sortedNumbers = callCounts.keys.toList()
      ..sort((a, b) => callCounts[a]!.compareTo(callCounts[b]!));

    // Get the contacts corresponding to the least called numbers
    List<Contact> leastCalledContacts = [];
    for (String number in sortedNumbers) {
      Contact? contact = contacts.firstWhere(
            (contact) => contact.phones?.first.value == number,
        orElse: () => Contact(), // Boş bir Contact nesnesi döndürüyoruz.
      );
      if (contact.displayName != null && contact.displayName!.isNotEmpty) {
        leastCalledContacts.add(contact);
      }
    }

    // Limiting to top 10 least called contacts for example
    return leastCalledContacts.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Deletion Process'),
      ),
      body: _contacts.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          ExpansionTile(
            title: Text('Things Not Spoken in the Last 6 Months'),
            children: _buildContactList(_inactiveContacts),
          ),
          ExpansionTile(
            title: Text('Among My Contacts, Those I Have Made the Least Phone Calls With'),
            children: _buildContactList(_leastCalledContacts),
          ),
        ],
      ),
    );
  }

  // Kişi listesi oluşturma işlevi
  List<Widget> _buildContactList(List<Contact> contacts) {
    return contacts.map((contact) {
      return ListTile(
        title: Text(contact.displayName ?? ''),
        subtitle: Text(contact.phones?.first.value ?? ''),
        trailing: IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            _showDeleteConfirmationDialog(contact);
          },
        ),
      );
    }).toList();
  }

  // Silme işlemi onayı için bir dialog gösterme işlevi
  Future<void> _showDeleteConfirmationDialog(Contact contact) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Kişiyi Sil'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('\'${contact.displayName}\' Are you sure you want to delete the contact?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                _deleteContact(contact);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Kişiyi silme işlevi
  void _deleteContact(Contact contact) async {
    await ContactsService.deleteContact(contact);
    setState(() {
      _contacts.remove(contact);
    });
    print('\'${contact.displayName}\' contact was deleted.');
  }
}

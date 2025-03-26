import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EventScreen(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance.db');
    await deleteDatabase(path);
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance.db');
    return await openDatabase(
      path,
      version: 1, // Set the version to 1 to recreate the database
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            cutoff_time TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id INTEGER,
            name TEXT,
            position TEXT,
            time_in TEXT,
            FOREIGN KEY (event_id) REFERENCES events(id)
          );
        ''');
      },
    );
  }

  Future<int> insertEvent(String name, String cutoffTime) async {
    final db = await database;
    return await db.insert('events', {
      'name': name,
      'cutoff_time': cutoffTime,
    });
  }

  Future<Map<String, dynamic>> getEvent(int eventId) async {
    final db = await database;
    final result = await db.query('events', where: 'id = ?', whereArgs: [eventId]);
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getEvents() async {
    final db = await database;
    return await db.query('events');
  }

  String formattedTime() {
    return DateFormat('hh:mm a').format(DateTime.now()); // 12-hour format with AM/PM
  }

  Future<int> insertAttendance(int eventId, String name, String position) async {
    final db = await database;
    String timeIn = formattedTime(); // Use formatted time
    return await db.insert('attendance', {
      'event_id': eventId,
      'name': name,
      'position': position,
      'time_in': timeIn
    });
  }

  Future<List<Map<String, dynamic>>> getAttendance(int eventId) async {
    final db = await database;
    return await db.query('attendance', where: 'event_id = ?', whereArgs: [eventId]);
  }

  Future<int> deleteEvent(int eventId) async {
    final db = await database;
    // Delete related attendance first (to avoid foreign key constraint issues)
    await db.delete('attendance', where: 'event_id = ?', whereArgs: [eventId]);
    return await db.delete('events', where: 'id = ?', whereArgs: [eventId]);
  }

  Future<int> deleteAttendance(int attendanceId) async {
    final db = await database;
    return await db.delete('attendance', where: 'id = ?', whereArgs: [attendanceId]);
  }
}

class EventScreen extends StatefulWidget {
  @override
  _EventScreenState createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final TextEditingController _eventController = TextEditingController();
  List<Map<String, dynamic>> events = [];
  bool showAllEvents = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    events = await DatabaseHelper.instance.getEvents();
    print('Loaded events: $events'); // Debug print
    setState(() {});
  }

  Future<void> _addEvent() async {
    if (_eventController.text.isNotEmpty) {
      try {
        TimeOfDay? selectedTime = await showTimePicker(
          context: this.context,
          initialTime: TimeOfDay.now(),
          helpText: "Select cut off time",
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: ThemeData.light().copyWith(
                primaryColor: Colors.red,
                colorScheme: ColorScheme.light(primary: Colors.red, secondary: Colors.red),
                buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
              ),
              child: child!,
            );
          },
        );

        if (selectedTime != null) {
          final now = DateTime.now();
          final cutoffDateTime = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
          String formattedTime = DateFormat('hh:mm a').format(cutoffDateTime);

          print("Attempting to insert event: ${_eventController.text}, Time: $formattedTime");

          int eventId = await DatabaseHelper.instance.insertEvent(_eventController.text, formattedTime);

          if (eventId > 0) {
            print("✅ Event added successfully! ID: $eventId");
            _eventController.clear();
            await _loadEvents(); // Refresh the list
          } else {
            print("❌ Failed to insert event. Check database logic.");
          }
        }
      } catch (e) {
        print("⚠️ Error adding event: $e");
      }
    } else {
      print("⚠️ Event name is empty. Skipping insertion.");
    }
  }

  String getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning, User";
    } else if (hour < 18) {
      return "Good Afternoon, User";
    } else {
      return "Good Evening, User";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'SALIS',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.white.withOpacity(0.3)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.red, Colors.yellow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    getGreeting(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 53,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 0.95,
                    ),
                  ),
                ),
                SizedBox(height: 24.0), // Add spacing between greeting and input field
                Container(
                  width: 310,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17.0),
                    border: Border.all(color: Colors.red, width: 1.0),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _eventController,
                        decoration: InputDecoration(
                          labelText: 'Event Name',
                          labelStyle: TextStyle(color: Colors.red),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      SizedBox(height: 8.0),
                      ElevatedButton(
                        onPressed: _addEvent,
                        child: Text('Add Event'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 36), // Make the button span the width of the container
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.0), // Add spacing between input field and event list
                Container(
                  width: 310,
                  child: events.isEmpty
                      ? Center(
                          child: Text(
                            'Add an event to track attendance!',
                            style: TextStyle(color: Colors.red, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        )
                      : Column(
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: showAllEvents ? events.length : (events.length > 3 ? 3 : events.length),
                              itemBuilder: (context, index) {
                                return Dismissible(
                                  key: Key(events[index]['id'].toString()),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (direction) async {
                                    await DatabaseHelper.instance.deleteEvent(events[index]['id']);
                                    _loadEvents(); // Refresh event list after deletion
                                  },
                                  background: Container(
                                    color: Colors.transparent,
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.symmetric(horizontal: 20),
                                    child: Icon(Icons.delete, color: Colors.red),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 241, 88, 78),
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTile(
                                      title: Text(
                                        events[index]['name'],
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'Cutoff Time: ${events[index]['cutoff_time']}',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AttendanceScreen(eventId: events[index]['id']),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (events.length > 3 && !showAllEvents)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    showAllEvents = true;
                                  });
                                  Scrollable.ensureVisible(context, duration: Duration(milliseconds: 300));
                                },
                                child: Text('See All Events'),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  final int eventId;

  QRScannerScreen({required this.eventId});

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanningAllowed = true;

  void _resetScanning() {
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _isScanningAllowed = true;
      });
    });
  }

  String? _extractData(String rawValue, String startSeparator, String endSeparator) {
    final startIndex = rawValue.indexOf(startSeparator);
    if (startIndex == -1) return null;
    final endIndex = rawValue.indexOf(endSeparator, startIndex + startSeparator.length);
    if (endIndex == -1) return null;
    return rawValue.substring(startIndex + startSeparator.length, endIndex).trim();
  }

  String? _extractName(String rawValue) {
    return _extractData(rawValue, "N:", "P:")?.toUpperCase();
  }

  String? _extractPosition(String rawValue) {
    final startIndex = rawValue.indexOf("P:");
    if (startIndex == -1) return null;
    return rawValue.substring(startIndex + 2).trim().toUpperCase();
  }

  Future<void> _updateOrInsertAttendance(int eventId, String name, String position) async {
    final db = await DatabaseHelper.instance.database;
    final existingAttendance = await db.query(
      'attendance',
      where: 'event_id = ? AND name = ?',
      whereArgs: [eventId, name],
    );

    if (existingAttendance.isNotEmpty) {
      final currentTime = DatabaseHelper.instance.formattedTime();
      final existingTimeIn = existingAttendance.first['time_in'];
      final updatedTimeIn = '$existingTimeIn | $currentTime';

      await db.update(
        'attendance',
        {'time_in': updatedTimeIn},
        where: 'id = ?',
        whereArgs: [existingAttendance.first['id']],
      );
    } else {
      await DatabaseHelper.instance.insertAttendance(eventId, name, position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan QR Code')),
      body: MobileScanner(
        onDetect: (capture) async {
          if (!_isScanningAllowed) return;

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final barcode = barcodes.first;
            final rawValue = barcode.rawValue;
            if (rawValue != null) {
              final name = _extractName(rawValue);
              final position = _extractPosition(rawValue);

              if (name != null && position != null) {
                setState(() {
                  _isScanningAllowed = false;
                });

                final db = await DatabaseHelper.instance.database;
                final existingAttendance = await db.query(
                  'attendance',
                  where: 'event_id = ? AND name = ?',
                  whereArgs: [widget.eventId, name],
                );

                if (existingAttendance.isNotEmpty) {
                  final timeInCount = (existingAttendance.first['time_in'] as String? ?? '').split('|').length;

                  if (timeInCount >= 2) {
                    await showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text("Already Timed In and Out"),
                        content: Text("This officer has already timed in and out."),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _resetScanning();
                            },
                            child: Text("Close"),
                          ),
                        ],
                      ),
                    );
                  } else {
                    await showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(timeInCount == 1 ? "Confirm Time Out" : "Confirm Time In"),
                        content: Text("Is this correct?\nName: $name\nPosition: $position"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _resetScanning();
                            },
                            child: Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _updateOrInsertAttendance(widget.eventId, name, position);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Attendance recorded for $name',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: const Color.fromARGB(255, 241, 202, 47),
                                ),
                              );
                              Navigator.pop(context); // Close the dialog
                              Navigator.pop(context); // Close the QRScannerScreen
                            },
                            child: Text("Confirm"),
                          ),
                        ],
                      ),
                    );
                  }
                } else {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text("Confirm Time In"),
                      content: Text("Is this correct?\nName: $name\nPosition: $position"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _resetScanning();
                          },
                          child: Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _updateOrInsertAttendance(widget.eventId, name, position);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Attendance recorded for $name',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.yellow,
                              ),
                            );
                            Navigator.pop(context); // Close the dialog
                            Navigator.pop(context); // Close the QRScannerScreen
                          },
                          child: Text("Confirm"),
                        ),
                      ],
                    ),
                  );
                }
              }
            }
          }
        },
      ),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  final int eventId;

  AttendanceScreen({required this.eventId});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Map<String, dynamic>> attendanceList = [];
  String cutoffTime = '';

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    attendanceList = await DatabaseHelper.instance.getAttendance(widget.eventId);
    final event = await DatabaseHelper.instance.getEvent(widget.eventId);
    final cutoffTime = event['cutoff_time'];
    setState(() {
      this.cutoffTime = cutoffTime;
    });
  }

  bool isLate(String timeIn, String cutoffTime) {
    final format = DateFormat('hh:mm a');
    final timeInDate = format.parse(timeIn);
    final cutoffTimeDate = format.parse(cutoffTime);
    return timeInDate.isAfter(cutoffTimeDate);
  }

  void _scanQRCode() {
    Navigator.push(
      this.context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(eventId: widget.eventId),
      ),
    ).then((_) => _loadAttendance());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: attendanceList.length,
              itemBuilder: (context, index) {
                final isLateFlag = isLate(attendanceList[index]['time_in'], cutoffTime);
                return Container(
                  color: isLateFlag ? Colors.red : Colors.green,
                  child: ListTile(
                    title: Text(
                      attendanceList[index]['name'],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${attendanceList[index]['position']} - ${attendanceList[index]['time_in']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.white),
                      onPressed: () async {
                        await DatabaseHelper.instance.deleteAttendance(attendanceList[index]['id']);
                        _loadAttendance(); // Refresh list after deletion
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _scanQRCode,
            child: Text('Scan QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          SizedBox(height: 16.0), // Add spacing from the bottom
        ],
      ),
    );
  }
}
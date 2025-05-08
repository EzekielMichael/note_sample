import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'database_helper2.dart'; // Ensure to import your DatabaseHelper

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  _CalendarWidgetState createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  List<Event> _events = []; // List to hold event objects
  Event? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _loadEvents(); // Load events from the database
  }

  Future<void> _loadEvents() async {
    final db = DatabaseHelper2();
    final eventRows = await db.getEvents();
    setState(() {
      _events = eventRows.map((row) {
        return Event(
          row['id'], // Include ID for updating/deleting
          row['title'],
          row['description'],
          DateTime.parse(row['date']),
          TimeOfDay.fromDateTime(DateTime.parse(row['time'])),
        );
      }).toList();
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;

        // Check if there is an event for the selected day
        bool hasEvent = _events.any((event) => isSameDay(event.date, selectedDay));

        // Set _selectedEvent based on the presence of events
        if (hasEvent) {
          _selectedEvent = _events.firstWhere((event) => isSameDay(event.date, selectedDay));
        } else {
          _selectedEvent = null; // No event found
        }
      });
    }
  }

  void _showEventDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return EventDialog(
          onEventAdded: (title, description, date, time) {
            setState(() {
              final newEvent = Event(0, title, description, date, time); // ID set to 0 for new events
              _events.add(newEvent);
              _saveEventToDatabase(newEvent);
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _saveEventToDatabase(Event event) async {
    final db = DatabaseHelper2();
    await db.insertEvent({
      'title': event.title,
      'description': event.description,
      'date': event.date.toIso8601String(),
      'time': event.timeToDateTime().toIso8601String(),
    });

    // Schedule the notification
    print("Event saved to database: ${event.title}"); // Log the event title
  }

  Future<void> _updateEventInDatabase(Event event) async {
    final db = DatabaseHelper2();
    await db.updateEvent(event.id, {
      'title': event.title,
      'description': event.description,
      'date': event.date.toIso8601String(),
      'time': event.timeToDateTime().toIso8601String(),
    });
  }

  Future<void> _deleteEventFromDatabase(int id) async {
    final db = DatabaseHelper2();
    await db.deleteEvent(id);
  }

  void _showUpdateEventDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) {
        return EventDialog(
          onEventAdded: (title, description, date, time) {
            setState(() {
              // Update the event in the list and database
              event.title = title;
              event.description = description;
              event.date = date;
              event.time = time;
              _updateEventInDatabase(event);
            });
            Navigator.of(context).pop();
          },
          initialTitle: event.title,
          initialDescription: event.description,
          initialDate: event.date,
          initialTime: event.time,
        );
      },
    );
  }

  void _deleteEvent(Event event) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Event'),
          content: Text('Are you sure you want to delete this event?'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _events.remove(event);
                  _deleteEventFromDatabase(event.id);
                });
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showAllEventsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('All Events'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _events.isNotEmpty
                  ? _events.map((event) {
                return ListTile(
                  title: Text(event.title),
                  subtitle: Text('${DateFormat('yyyy-MM-dd').format(event.date.toLocal())} at ${event.time.format(context)}'),
                  onTap: () => _showUpdateEventDialog(event),
                );
              }).toList()
                  : [Text('No events added')],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        title: Text('Calendar'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showEventDialog,
          ),
          IconButton(
            icon: Icon(Icons.list),
            onPressed: _showAllEventsDialog, // Button to show all events
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              Colors.cyan,
            ],
          ),
        ),
        child: Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: _onDaySelected,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (_events.any((event) => isSameDay(event.date, date))) {
                        return Positioned(
                          bottom: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            width: 6,
                            height: 6,
                          ),
                        );
                      }
                      return SizedBox(); // Return an empty widget if no marker
                    },
                  ),
                ),
                if (_selectedEvent != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Details:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Title: ${_selectedEvent!.title}'),
                        Text('Description: ${_selectedEvent!.description}'),
                        Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedEvent!.date.toLocal())}'),
                        Text('Time: ${_selectedEvent!.time.format(context)}'),
                        SizedBox(height: 16),
                        // Update and Delete buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: () => _showUpdateEventDialog(_selectedEvent!),
                              child: Text('Update Event'),
                            ),
                            ElevatedButton(
                              onPressed: () => _deleteEvent(_selectedEvent!),
                              child: Text('Delete Event'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No events for this date.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Event {
  final int id; // Include ID for updating/deleting
  String title;
  String description;
  DateTime date;
  TimeOfDay time;

  Event(this.id, this.title, this.description, this.date, this.time);

  DateTime timeToDateTime() {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class EventDialog extends StatefulWidget {
  final Function(String, String, DateTime, TimeOfDay) onEventAdded;
  final String? initialTitle;
  final String? initialDescription;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;

  const EventDialog({super.key,
    required this.onEventAdded,
    this.initialTitle,
    this.initialDescription,
    this.initialDate,
    this.initialTime,
  });

  @override
  _EventDialogState createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _eventDate;
  TimeOfDay? _eventTime;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    _descriptionController.text = widget.initialDescription ?? '';
    _eventDate = widget.initialDate;
    _eventTime = widget.initialTime;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() {
        _eventDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _eventTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        _eventTime = pickedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialTitle == null ? 'Add Event' : 'Update Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Event Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () => _selectDate(context),
              child: Text('Select Date'),
            ),
            if (_eventDate != null)
              Text('Selected Date: ${DateFormat('yyyy-MM-dd').format(_eventDate!)}'),
            SizedBox(height: 10),
            TextButton(
              onPressed: () => _selectTime(context),
              child: Text('Select Time'),
            ),
            if (_eventTime != null)
              Text('Selected Time: ${_eventTime!.format(context)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_eventDate != null && _eventTime != null) {
              widget.onEventAdded(
                _titleController.text,
                _descriptionController.text,
                _eventDate!,
                _eventTime!,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Please select a date and time")),
              );
            }
          },
          child: Text(widget.initialTitle == null ? 'Add Event' : 'Update Event'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
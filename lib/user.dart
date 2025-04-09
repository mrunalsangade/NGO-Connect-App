import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final String userName;
  final String firstName;
  final String lastName;
  final String email;
  final String dob;

  HomeScreen({
    this.initialIndex = 0,
    required this.userName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.dob,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      EventCalendar(),
      DashboardGrid(
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: widget.email,
        dob: widget.dob,
      ),
      ContributionScreen(userEmail: widget.email),
    ]);
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _currentIndex == 0
            ? Text("Events Calendar")
            : _currentIndex == 1
                ? Text("Dashboard")
                : null,
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserDetailsScreen(
                    userName: widget.userName,
                    firstName: widget.firstName,
                    lastName: widget.lastName,
                    email: widget.email,
                    dob: widget.dob,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text("U", style: TextStyle(color: Colors.green)),
              ),
            ),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(
              icon: Icon(Icons.attach_money), label: "Contribute"),
        ],
      ),
    );
  }
}

// 👤 User Details
class UserDetailsScreen extends StatelessWidget {
  final String userName;
  final String firstName;
  final String lastName;
  final String email;
  final String dob;

  UserDetailsScreen({
    required this.userName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.dob,
  });

  // Logout function using FirebaseAuth; adjust as needed.
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SelectUserScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logout failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the firstName to compute the initial; fallback if empty.
    String initial = "";
    if (firstName.trim().isNotEmpty) {
      initial = firstName.trim()[0].toUpperCase();
    } else if (userName.trim().isNotEmpty) {
      initial = userName.trim()[0].toUpperCase();
    } else {
      initial = "N";
    }

    final fullName = (firstName.trim() + " " + lastName.trim()).trim();
    final displayName = fullName.isNotEmpty ? fullName : userName;

    return Scaffold(
      appBar: AppBar(
        title: Text("User Profile"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: Center(
        child: Card(
          elevation: 4,
          margin: EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with avatar + name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.green,
                      child: Text(
                        initial,
                        style: TextStyle(fontSize: 28, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Divider(),
                SizedBox(height: 8),
                Text("User Name: $displayName", style: TextStyle(fontSize: 16)),
                SizedBox(height: 8),
                Text("Email: $email", style: TextStyle(fontSize: 16)),
                SizedBox(height: 8),
                Text("DOB: $dob", style: TextStyle(fontSize: 16)),
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.logout),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _logout(context),
                    label: Text("Logout"),
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

// 📅 Event Calendar
class EventCalendar extends StatefulWidget {
  const EventCalendar({Key? key}) : super(key: key);

  @override
  _EventCalendarState createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Map to store events where the key is the event date (year, month, day)
  // and the value is a list of event objects (maps with name, time, venue, essentials)
  Map<DateTime, List<Map<String, dynamic>>> _eventsMap = {};

  /// Returns the list of events for a given day from _eventsMap.
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _eventsMap[DateTime(day.year, day.month, day.day)] ?? [];
  }

  /// Process the Firestore snapshot and populate _eventsMap.
  void _loadEvents(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _eventsMap.clear();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['date'] != null && data['name'] != null) {
        try {
          // Convert the 'date' field (Timestamp or String) into DateTime.
          DateTime rawDate;
          if (data['date'] is Timestamp) {
            rawDate = (data['date'] as Timestamp).toDate();
          } else {
            rawDate = DateTime.parse(data['date']);
          }
          final eventDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

          // Build the event object.
          final eventObj = {
            'name': data['name'] ?? '',
            'time': data['time'] ?? '',
            'venue': data['venue'] ?? '',
            'essentials': data['essentials'] ?? '',
          };

          if (_eventsMap[eventDate] == null) {
            _eventsMap[eventDate] = [eventObj];
          } else {
            _eventsMap[eventDate]!.add(eventObj);
          }
        } catch (e) {
          debugPrint("Error parsing event data: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use withConverter to ensure correct typing of Firestore data.
    final eventsRef = FirebaseFirestore.instance
        .collection('events')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (data, _) => data,
        );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: eventsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading events"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        // Populate _eventsMap from the Firestore snapshot.
        _loadEvents(snapshot.data!);

        return Column(
          children: [
            TableCalendar(
              focusedDay: _focusedDay,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: (day) => _getEventsForDay(day),
            ),
            // List events for the selected day.
            ..._getEventsForDay(_selectedDay ?? _focusedDay)
                .map(
                  (event) => Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(event['name'] ?? ''),
                      subtitle: Text(
                        "Time: ${event['time']}\n"
                        "Venue: ${event['venue']}\n"
                        "Essentials: ${event['essentials']}",
                      ),
                    ),
                  ),
                )
                .toList(),
          ],
        );
      },
    );
  }
}

// 🧩 Dashboard Grid
class DashboardGrid extends StatelessWidget {
  final String firstName, lastName, email, dob;

  DashboardGrid({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.dob,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _card(
          context,
          Icons.volunteer_activism,
          "Volunteer for Events",
          VolunteerForm(
            firstName: firstName,
            lastName: lastName,
            email: email,
            dob: dob,
          ),
        ),
        _card(context, Icons.people, "Meet Our Team", TeamScreen()),
        _card(context, Icons.feedback, "Feedback", FeedbackScreen()),
        _card(context, Icons.help_outline, "FAQs", FAQScreen()),
      ],
    );
  }

  Widget _card(
      BuildContext context, IconData icon, String title, Widget screen) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      ),
    );
  }
}

// 👥 Meet Our Team Page
class TeamScreen extends StatelessWidget {
  final List<Map<String, String>> team = [
    {"name": "Mrunal Sangade", "role": "Event In-Charge"},
    {"name": "Arya Sadigale", "role": "Campaign In-Charge"},
    {"name": "Atharva Urankar", "role": "Operations In-Charge"},
    {"name": "Soham Ghogare", "role": "Volunteer In-Charge"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Our Team")),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: team.length,
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.person, color: Colors.green),
              title: Text(team[index]['name']!),
              subtitle: Text(team[index]['role']!),
            ),
          );
        },
      ),
    );
  }
}

// 🙋 Volunteer Form (Updated to Volunteer for Events)
class VolunteerForm extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String dob; // if needed

  VolunteerForm({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.dob,
  });

  @override
  _VolunteerFormState createState() => _VolunteerFormState();
}

class _VolunteerFormState extends State<VolunteerForm> {
  final CollectionReference<Map<String, dynamic>> eventsRef =
      FirebaseFirestore.instance.collection('events');

  /// Helper method to convert a Firestore date (Timestamp or String) into a readable string.
  String formatDate(dynamic dateField) {
    if (dateField == null) return "N/A";

    // If it's a Firestore Timestamp, convert to DateTime.
    if (dateField is Timestamp) {
      DateTime dt = dateField.toDate();
      // Format as desired, e.g. "01 Apr 2025"
      return DateFormat("dd MMM yyyy").format(dt);
    }
    // If it's already a string (e.g., "2025-04-01"), you can parse or directly show it.
    if (dateField is String) {
      try {
        DateTime dt = DateTime.parse(dateField);
        return DateFormat("dd MMM yyyy").format(dt);
      } catch (_) {
        // If it doesn't parse, just return the raw string
        return dateField;
      }
    }
    // Fallback
    return dateField.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Volunteer for Events")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: eventsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading events"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text("No events found."));
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final eventName = data['name'] ?? 'Unnamed Event';
              final dateRaw = data['date']; // Could be Timestamp or String
              final dateFormatted = formatDate(dateRaw);

              final time = data['time'] ?? 'N/A';
              final venue = data['venue'] ?? 'N/A';
              final essentials = data['essentials'] ?? 'N/A';

              return Card(
                margin: EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text("Date: $dateFormatted"),
                      Text("Time: $time"),
                      Text("Venue: $venue"),
                      Text("Essentials: $essentials"),
                      SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () async {
                            // Create a new document in 'volunteers' collection
                            await FirebaseFirestore.instance
                                .collection('volunteers')
                                .add({
                              'name': "${widget.firstName} ${widget.lastName}",
                              'email': widget.email,
                              'dob': widget.dob, // if storing DOB
                              'event': eventName,
                              'date': dateFormatted,
                              'time': time,
                              'venue': venue,
                              'essentials': essentials,
                            });

                            // Show confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    "You have volunteered for $eventName!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: Text("Volunteer"),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 🗣️ Feedback Form
class FeedbackScreen extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController feedbackController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Feedback")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                "Tell us what you think or suggest improvements.",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Your Feedback",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Please write something" : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text("Send Feedback"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Feedback submitted!"),
                      backgroundColor: Colors.green,
                    ));
                    feedbackController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 💸 Contribute Page (Volunteer Time Removed)
/// -------------------------
/// Contribution Screen
/// -------------------------
class ContributionScreen extends StatelessWidget {
  final String userEmail;

  ContributionScreen({required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.favorite, size: 50, color: Colors.red),
        SizedBox(height: 10),
        Text(
          "Choose How You'd Like to Help",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Divider(),
        _tile(
          context,
          "Donate Funds",
          "Support us financially.",
          DonateFundsPage(userEmail: userEmail),
        ),
        _tile(
          context,
          "Donate Supplies",
          "Clothes, food, etc.",
          DonateSuppliesPage(userEmail: userEmail),
        ),
      ],
    );
  }

  Widget _tile(
      BuildContext context, String title, String subtitle, Widget screen) {
    return ListTile(
      leading: Icon(Icons.arrow_forward, color: Colors.green),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: ElevatedButton(
        child: Text("Select"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
      ),
    );
  }
}

/// -------------------------
/// Donate Funds Page
/// -------------------------
class DonateFundsPage extends StatefulWidget {
  final String userEmail;
  DonateFundsPage({required this.userEmail});

  @override
  _DonateFundsPageState createState() => _DonateFundsPageState();
}

class _DonateFundsPageState extends State<DonateFundsPage> {
  final _formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  String? selectedMethod;
  final List<String> paymentMethods = ["Cash", "UPI", "Bank Transfer"];

  // Fetch user from Firestore based on userEmail
  Future<Map<String, dynamic>?> _fetchUser() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }
    return null;
  }

  Future<void> _donateFunds(String fullName) async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await FirebaseFirestore.instance.collection('contributions_fund').add({
        'name': fullName, // Fetched full name from the users collection
        'amount': amountController.text,
        'paymentMethod': selectedMethod,
        'status': "Pending", // default status
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Donation submitted successfully!")),
      );
      amountController.clear();
      setState(() {
        selectedMethod = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Donate Funds")),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUser(),
        builder: (context, snapshot) {
          // Loading indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // Error handling
          if (snapshot.hasError || snapshot.data == null) {
            return Center(child: Text("Error fetching user info"));
          }
          final userData = snapshot.data!;
          final fullName = "${userData['firstName']} ${userData['lastName']}";

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Display user's full name (read-only)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Name: $fullName",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: InputDecoration(labelText: "Amount"),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return "Please enter an amount";
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration: InputDecoration(labelText: "Payment Method"),
                    items: paymentMethods
                        .map((method) => DropdownMenuItem(
                              value: method,
                              child: Text(method),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedMethod = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? "Please select a payment method" : null,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _donateFunds(fullName),
                    child: Text("Donate"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// -------------------------
/// Donate Supplies Page
/// -------------------------
class DonateSuppliesPage extends StatefulWidget {
  final String userEmail;
  DonateSuppliesPage({required this.userEmail});

  @override
  _DonateSuppliesPageState createState() => _DonateSuppliesPageState();
}

class _DonateSuppliesPageState extends State<DonateSuppliesPage> {
  final _formKey = GlobalKey<FormState>();
  final suppliesController = TextEditingController();
  String? selectedLocation;
  final List<String> locations = ["Center A", "Center B"];
  // Full addresses for display only (only "Center A" or "Center B" will be stored)
  final Map<String, String> locationAddresses = {
    "Center A": "123 Main Street, City, Country",
    "Center B": "456 Another Road, City, Country",
  };

  // Fetch user from Firestore based on userEmail
  Future<Map<String, dynamic>?> _fetchUser() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }
    return null;
  }

  Future<void> _submitSupplies(String fullName) async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await FirebaseFirestore.instance
          .collection('contributions_supplies')
          .add({
        'name': fullName, // Fetched full name from the users collection
        'supplyItem': suppliesController.text,
        'location': selectedLocation, // Only "Center A" or "Center B" is stored
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Supply donation submitted successfully!")),
      );
      suppliesController.clear();
      setState(() {
        selectedLocation = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    suppliesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Donate Supplies")),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUser(),
        builder: (context, snapshot) {
          // Loading indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // Error handling
          if (snapshot.hasError || snapshot.data == null) {
            return Center(child: Text("Error fetching user info"));
          }
          final userData = snapshot.data!;
          final fullName = "${userData['firstName']} ${userData['lastName']}";

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Display user's full name (read-only)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Name: $fullName",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: suppliesController,
                    decoration: InputDecoration(
                      labelText: "Supplies (e.g. Clothes, Food, Books)",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return "Please specify supplies";
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedLocation,
                    decoration: InputDecoration(labelText: "Delivery Location"),
                    items: locations
                        .map((loc) => DropdownMenuItem(
                              value: loc,
                              child: Text(loc),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => selectedLocation = val),
                    validator: (value) => value == null
                        ? "Please select a delivery location"
                        : null,
                  ),
                  if (selectedLocation != null) ...[
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        locationAddresses[selectedLocation!] ?? "",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _submitSupplies(fullName),
                    child: Text("Submit"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ❓ FAQs Page
class FAQScreen extends StatelessWidget {
  final faqs = [
    {
      "q": "How can I volunteer?",
      "a": "Go to Dashboard > Volunteer for Events."
    },
    {
      "q": "How do I donate?",
      "a": "Go to Contribute > Choose option to donate."
    },
    {
      "q": "Where are events conducted?",
      "a": "Event locations vary and are listed on the Events page."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("FAQs")),
      body: ListView.builder(
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          return ExpansionTile(
            title: Text(faqs[index]["q"]!),
            children: [
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(faqs[index]["a"]!))
            ],
          );
        },
      ),
    );
  }
}

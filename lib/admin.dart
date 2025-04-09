import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 1;

  final List<Widget> _pages = [
    ManageUsersScreen(),
    AdminDashboard(),
    ReportsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Users"),
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(
              icon: Icon(Icons.insert_chart), label: "Reports"),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _adminCard(context, Icons.event, "Manage Events",
              "Update or schedule events.", EventManagementScreen()),
          _adminCard(context, Icons.feedback, "Read Feedback",
              "See what users are saying.", FeedbackManagementScreen()),
          _adminCard(context, Icons.assignment_ind, "View Volunteer Forms",
              "Details of volunteer applications.", VolunteerFormsScreen()),
          _adminCard(
              context,
              Icons.card_giftcard,
              "View Contributions",
              "Details of funds/supplies donated.",
              ContributionDetailsScreen()),
        ],
      ),
    );
  }

  Widget _adminCard(BuildContext context, IconData icon, String title,
      String subtitle, Widget navigateTo) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 40, color: Colors.green),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => navigateTo)),
      ),
    );
  }
}

// ✅ Manage Users from Firestore
class ManageUsersScreen extends StatelessWidget {
  final CollectionReference usersRef =
      FirebaseFirestore.instance.collection('users');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Manage Users"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return Center(child: Text("No users found."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final user = docs[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text("${user['firstName']} ${user['lastName']}"),
                  leading: Icon(Icons.person, color: Colors.green),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Email: ${user['email']}"),
                          Text("DOB: ${user['dob']}"),
                          SizedBox(height: 10),
                          ElevatedButton.icon(
                            icon: Icon(Icons.delete),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () {
                              usersRef.doc(docs[index].id).delete();
                            },
                            label: Text("Delete"),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EventManagementScreen extends StatefulWidget {
  @override
  _EventManagementScreenState createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  final CollectionReference eventsRef =
      FirebaseFirestore.instance.collection('events');

  void _openEventForm({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    final Map<String, dynamic> data =
        doc?.data() as Map<String, dynamic>? ?? {};
    final TextEditingController name =
        TextEditingController(text: data["name"] ?? "");
    final TextEditingController time =
        TextEditingController(text: data["time"] ?? "");
    final TextEditingController venue =
        TextEditingController(text: data["venue"] ?? "");
    final TextEditingController essentials =
        TextEditingController(text: data["essentials"] ?? "");
    DateTime? selectedDate =
        data["date"] != null ? (data["date"] as Timestamp).toDate() : null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? "Edit Event" : "Add Event"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: "Event Name")),
              TextField(
                  controller: time,
                  decoration: InputDecoration(labelText: "Time")),
              TextField(
                  controller: venue,
                  decoration: InputDecoration(labelText: "Venue")),
              TextField(
                  controller: essentials,
                  decoration: InputDecoration(labelText: "Essentials")),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
                child: Text("Select Date"),
              ),
              Text(selectedDate != null
                  ? DateFormat('dd MMM yyyy').format(selectedDate!)
                  : "No date selected")
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (name.text.isNotEmpty &&
                  time.text.isNotEmpty &&
                  venue.text.isNotEmpty &&
                  essentials.text.isNotEmpty &&
                  selectedDate != null) {
                final newEvent = {
                  "name": name.text,
                  "time": time.text,
                  "venue": venue.text,
                  "essentials": essentials.text,
                  "date": Timestamp.fromDate(selectedDate!)
                };
                if (isEdit) {
                  eventsRef.doc(doc!.id).update(newEvent);
                } else {
                  eventsRef.add(newEvent);
                }
                Navigator.pop(context);
              }
            },
            child: Text(isEdit ? "Update" : "Add"),
          ),
        ],
      ),
    );
  }

  void _deleteEvent(String id) {
    eventsRef.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Events")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("Add an Event"),
              onPressed: () => _openEventForm(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: eventsRef.orderBy("date").snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final e = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        child: ExpansionTile(
                          title: Text(e["name"]),
                          subtitle: Text(
                            e["date"] is Timestamp
                                ? DateFormat("dd MMM yyyy")
                                    .format((e["date"] as Timestamp).toDate())
                                : DateFormat("dd MMM yyyy")
                                    .format(DateTime.parse(e["date"])),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () =>
                                      _openEventForm(doc: docs[index])),
                              IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () =>
                                      _deleteEvent(docs[index].id)),
                            ],
                          ),
                          children: [
                            ListTile(title: Text("Time: ${e["time"]}")),
                            ListTile(title: Text("Venue: ${e["venue"]}")),
                            ListTile(
                                title: Text("Essentials: ${e["essentials"]}")),
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
    );
  }
}

class VolunteerFormsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Volunteer Forms")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('volunteers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return Center(child: Text("No volunteer forms found."));

          final forms = snapshot.data!.docs;

          return ListView.builder(
            itemCount: forms.length,
            itemBuilder: (context, index) {
              final form = forms[index];
              final data = form.data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          Icon(Icons.volunteer_activism, color: Colors.green),
                      title: Text("${data['name']} - ${data['event']}"),
                      trailing: Icon(Icons.expand_more),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text("${data['name']} - ${data['event']}"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("📧 Email: ${data['email']}"),
                                Text("🎂 DOB: ${data['dob']}"),
                                SizedBox(height: 10),
                                Text("📅 Date: ${data['date']}"),
                                Text("⏰ Time: ${data['time']}"),
                                Text("📍 Venue: ${data['venue']}"),
                                Text("🎒 Essentials: ${data['essentials']}"),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("Close"),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ✅ View Contributions
class ContributionDetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Contributions"),
          bottom: TabBar(
            tabs: [
              Tab(text: "Funds"),
              Tab(text: "Supplies"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 🪙 Funds Contributions
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('contributions_fund')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final contributions = snapshot.data!.docs;
                if (contributions.isEmpty) {
                  return Center(child: Text("No fund contributions yet."));
                }
                return ListView.builder(
                  itemCount: contributions.length,
                  itemBuilder: (context, index) {
                    final doc = contributions[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        leading: Icon(Icons.payments, color: Colors.green),
                        title: Text("${data['name']}"),
                        subtitle: Text(
                          "Amount: ₹${data['amount']}\n"
                          "Method: ${data['paymentMethod']}\n"
                          "Status: ${data['status']}",
                        ),
                        // Only show Accept button if status is not "Success" yet
                        trailing: data['status'] != "Success"
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () async {
                                  try {
                                    // Update the document's status in Firestore
                                    await FirebaseFirestore.instance
                                        .collection('contributions_fund')
                                        .doc(doc.id)
                                        .update({'status': 'Success'});

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text("Status updated to Success!"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text("Error updating status: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Text("Accept"),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),

            // 🎁 Supplies Contributions
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('contributions_supplies')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final supplies = snapshot.data!.docs;
                if (supplies.isEmpty) {
                  return Center(child: Text("No supply contributions yet."));
                }
                return ListView.builder(
                  itemCount: supplies.length,
                  itemBuilder: (context, index) {
                    final doc = supplies[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        leading: Icon(Icons.card_giftcard, color: Colors.blue),
                        title: Text("${data['name']}"),
                        subtitle: Text(
                          "Supplies: ${data['supplyItem']}\n"
                          "Location: ${data['location']}",
                        ),
                        // If you also want an "Accept" button for supplies,
                        // ensure there's a 'status' field in your Firestore doc
                        // and replicate the same pattern:
                        // trailing: data['status'] != "Success" ? ...
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ Feedback View
class FeedbackManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("User Feedback")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('feedback').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading feedback"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text("No feedback yet."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final message = data['message'] ?? "No message";
              final userEmail = data['userEmail'] ?? "Unknown User";

              return ListTile(
                leading: Icon(Icons.feedback, color: Colors.green),
                title: Text(message),
                subtitle: Text(userEmail),
              );
            },
          );
        },
      ),
    );
  }
}

// ✅ Reports
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reports")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchReportData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While loading, show a spinner
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // In case of error, show a message
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            // If there's no data (null), show a fallback
            return Center(child: Text("No data available"));
          }

          // Extract the data from the snapshot
          final data = snapshot.data!;

          // Build a reports list similar to your original design
          final reports = [
            {
              "title": "Total Registered Users",
              "value": data['userCount'],
              "icon": Icons.person
            },
            {
              "title": "Donations Received",
              "value": "₹${data['totalDonations']}",
              "icon": Icons.attach_money
            },
            {
              "title": "Upcoming Events",
              "value": data['eventCount'],
              "icon": Icons.event
            },
            {
              "title": "Volunteers Registered",
              "value": data['volunteerCount'],
              "icon": Icons.volunteer_activism
            },
          ];

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(report["icon"], color: Colors.green),
                  title: Text(report["title"].toString()),
                  trailing: Text(
                    report["value"].toString(),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// This function runs multiple Firestore queries in parallel
  /// to get the data needed for reports, then returns them
  /// as a Map for easy access in the widget.
  Future<Map<String, dynamic>> _fetchReportData() async {
    // 1. Count of all users
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();
    final userCount = usersSnapshot.size;

    // 2. Sum of all successful donations
    //    (assuming 'amount' is stored as a string in Firestore)
    final fundSnapshot = await FirebaseFirestore.instance
        .collection('contributions_fund')
        .where('status', isEqualTo: 'Success')
        .get();

    double totalDonations = 0;
    for (var doc in fundSnapshot.docs) {
      final data = doc.data();
      if (data['amount'] != null) {
        // Convert the amount from string to double
        double parsedAmount = double.tryParse(data['amount']) ?? 0.0;
        totalDonations += parsedAmount;
      }
    }

    // 3. Count of events
    //    (If you want only future events, filter by date field instead)
    final eventsSnapshot =
        await FirebaseFirestore.instance.collection('events').get();
    final eventCount = eventsSnapshot.size;

    // 4. Count of volunteers
    final volunteersSnapshot =
        await FirebaseFirestore.instance.collection('volunteers').get();
    final volunteerCount = volunteersSnapshot.size;

    // Return everything as a single Map
    return {
      'userCount': userCount,
      'totalDonations': totalDonations.toStringAsFixed(0),
      // Round or format as needed
      'eventCount': eventCount,
      'volunteerCount': volunteerCount
    };
  }
}

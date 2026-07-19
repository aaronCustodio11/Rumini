import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class UserdashboardAnalytics extends StatefulWidget {
  final Map<String, dynamic> userData;
  const UserdashboardAnalytics({super.key, required this.userData});

  @override
  State<UserdashboardAnalytics> createState() => _UserdashboardAnalyticsState();
}

class _UserdashboardAnalyticsState extends State<UserdashboardAnalytics> {
  Map<String, int> roleCount = {};
  Map<String, int> counselorStudentCount = {};
  Map<String, int> collegeCount = {};
  int totalAssignedStudents = 0;
  bool isLoading = true;
  int? touchedIndex;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .get();
    final allUsers = usersSnapshot.docs.map((doc) => doc.data()).toList();

    final String role = widget.userData['role'] ?? '';
    final String currentCounId = widget.userData['counId'] ?? '';

    final bool isAdmin = role == 'Admin';
    final bool isCounselor = role == 'Counselor';

    List<Map<String, dynamic>> filteredUsers = allUsers;
    if (isCounselor) {
      filteredUsers = allUsers.where((user) {
        return user['role'] == 'Student' &&
            user['assignedCounselor'] == currentCounId;
      }).toList();
    }

    // Role distribution
    final Map<String, int> roleMap = {};
    for (var user in (isAdmin ? allUsers : filteredUsers)) {
      final role = user['role'] ?? 'Unknown';
      roleMap[role] = (roleMap[role] ?? 0) + 1;
    }

    // Students per counselor
    final Map<String, int> counselorMap = {};
    if (isAdmin) {
      for (var user in allUsers) {
        if (user['role'] == 'Student') {
          final assignedCounselor = user['assignedCounselor'] ?? 'Unassigned';
          counselorMap[assignedCounselor] =
              (counselorMap[assignedCounselor] ?? 0) + 1;
        }
      }
    }

    // Students per college
    final Map<String, int> collegeMap = {};
    for (var user in filteredUsers) {
      if (user['role'] == 'Student') {
        final college = user['college'] ?? 'Unknown';
        collegeMap[college] = (collegeMap[college] ?? 0) + 1;
      }
    }

    int totalAssigned = 0;
    if (isAdmin || isCounselor) {
      totalAssigned = allUsers
          .where(
            (u) =>
                u['role'] == 'Student' &&
                (u['assignedCounselor'] == currentCounId),
          )
          .length;
    }

    setState(() {
      roleCount = roleMap;
      counselorStudentCount = counselorMap;
      collegeCount = collegeMap;
      totalAssignedStudents = totalAssigned;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.userData['role'] ?? '';
    final bool isAdmin = role == 'Admin';
    final bool isCounselor = role == 'Counselor';

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📊 Dashboard Analytics",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // 🔹 ROW 1
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildMetricCard()),
              const SizedBox(width: 16),
              Expanded(
                child: isAdmin
                    ? _buildCard(
                        icon: Icons.pie_chart_rounded,
                        title: "User Role Distribution",
                        chart: _buildRolePieChart(),
                      )
                    : _buildCard(
                        icon: Icons.school_rounded,
                        title: "Students per College",
                        chart: _buildCollegeBarChart(),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 🔹 ROW 2 (Admin only)
          if (isAdmin)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCard(
                    icon: Icons.account_balance_rounded,
                    title: "Students per College",
                    chart: _buildCollegeBarChart(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCard(
                    icon: Icons.groups_rounded,
                    title: "Students per Counselor",
                    chart: _buildCounselorBarChart(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 🧩 Visually Enhanced Metric Card (UI/UX Only)
  Widget _buildMetricCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Icon(Icons.groups_rounded, size: 42, color: Colors.white),
              Icon(Icons.trending_up_rounded, size: 28, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),

          // Label
          const Text(
            "Total Students Assigned",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),

          // Main Count
          Text(
            "$totalAssignedStudents",
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 12),

          // Accent Line + Subtitle
          Row(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Updated automatically",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRolePieChart() {
    final total = roleCount.values.fold(0, (a, b) => a + b);
    if (total == 0) return const Text("No data available");

    // 🎨 Simple fixed color palette
    final List<Color> colorPalette = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
    ];

    final entries = roleCount.entries.toList();

    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 40,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            if (!event.isInterestedForInteractions ||
                pieTouchResponse?.touchedSection == null) {
              setState(() => touchedIndex = -1);
              return;
            }
            setState(
              () => touchedIndex =
                  pieTouchResponse!.touchedSection!.touchedSectionIndex,
            );
          },
        ),
        sections: List.generate(entries.length, (i) {
          final e = entries[i];
          final isTouched = i == touchedIndex;
          final percentage = (e.value / total) * 100;

          return PieChartSectionData(
            color: colorPalette[i % colorPalette.length],
            value: e.value.toDouble(),
            radius: isTouched ? 75 : 65, // 🔹 simple smooth hover grow
            title: '${e.key}\n${e.value} (${percentage.toStringAsFixed(1)}%)',
            titleStyle: TextStyle(
              fontSize: isTouched ? 13 : 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }

  // 📈 Bar Chart for Students per Counselor
  Widget _buildCounselorBarChart() {
    final entries = counselorStudentCount.entries.toList();
    if (entries.isEmpty) return const Text("No data available");

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                if (value.toInt() >= entries.length) return const SizedBox();
                return Transform.rotate(
                  angle: -0.5,
                  child: Text(
                    entries[value.toInt()].key,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value.toDouble(),
                width: 18,
                borderRadius: BorderRadius.circular(6),
                color: Colors.green,
              ),
            ],
          );
        }),
      ),
    );
  }

  // 📊 Bar Chart for Students per College
  Widget _buildCollegeBarChart() {
    final entries = collegeCount.entries.toList();
    if (entries.isEmpty) return const Text("No data available");

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          alignment: BarChartAlignment.spaceEvenly,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  if (value.toInt() >= entries.length) return const SizedBox();
                  return Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      entries[value.toInt()].key,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(entries.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.teal,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // 🧱 Card builder helper
  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget chart,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 250, child: chart),
          ],
        ),
      ),
    );
  }
}

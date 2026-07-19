import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Sidebar extends StatefulWidget {
  final Map<String, dynamic> userData;

  const Sidebar({super.key, required this.userData});

  @override
  _SidebarState createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  double collapsedWidth = 70;
  double expandedWidth = 250;
  String selectedRoute = "/ProfileAd";
  late bool isAdmin;

  @override
  void initState() {
    super.initState();
    _loadSidebarState();
    // Check if the user is an admin based on the role
    isAdmin = widget.userData['role'] == 'Admin';
  }

  void _loadSidebarState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isExpanded = prefs.getBool('sidebarExpanded') ?? false;
      selectedRoute = prefs.getString('selectedRoute') ?? "/ProfileAd";
    });
  }

  void _toggleSidebar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isExpanded = !isExpanded;
      prefs.setBool('sidebarExpanded', isExpanded);
    });
  }

  void _setSelectedRoute(String route) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedRoute = route;
      prefs.setString('selectedRoute', route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isExpanded ? expandedWidth : collapsedWidth,
      color: const Color(0xFF345F00),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(height: 20),
          Image.asset(
            isExpanded
                ? 'assets/images/logo(white).png'
                : 'assets/images/logosmall.png',
            width: isExpanded ? 200 : 70,
            height: isExpanded ? 200 : 70,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                // Common navigation items for both Admin and Counselor
                _buildNavItem(context, Icons.dashboard, "User Dashboard",
                    "/user_dashboard"),
                _buildNavItem(
                    context, Icons.event, "Appointments", "/appointments_ad"),
                _buildNavItem(context, Icons.school, "Psychoeducational",
                    "/psychoeducational_ad"),
                    _buildNavItem(
                      context, Icons.history, "Chat History", "/ChathistoryAd"),
                      _buildNavItem(
                        context, Icons.monitor_heart, "Monitoring", "/MonitorAd"),
                _buildNavItem(
                        context, Icons.feedback_outlined, "Feedback", "/FeedbackAd"),
            

                // Admin-only navigation items
                if (isAdmin) ...[
                  _buildNavItem(context, Icons.file_copy, "Forms", "/FormsAd"),
                  _buildNavItem(
                      context, Icons.chat_bubble, "Chatbot", "/ChatbotAd"),
                      _buildNavItem(
                      context, Icons.dashboard_customize_rounded, "Templates", "/TemplatesAd"),
                  
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white54),
          // _buildNavItem(context, Icons.logout, "Logout", "logout",
          //     isLogout: true),
          _buildNavItem(
                      context, Icons.person, "Profile", "/ProfileAd"),
          _buildExpandButton(),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, IconData icon, String title, String route,
      {bool isLogout = false}) {
    bool isSelected = selectedRoute == route;

    return InkWell(
      onTap: () {
        if (route == "logout") {
          _logout(context);
        } else {
          _setSelectedRoute(route);
          // Pass userData when navigating to different routes
          Navigator.pushReplacementNamed(
            context,
            route,
            arguments: widget.userData,
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius:
              isSelected ? BorderRadius.circular(8) : BorderRadius.zero,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color.fromARGB(0, 0, 0, 0).withAlpha(100),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment:
              isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? const Color(0xFF345F00) : Colors.white),
            if (isExpanded) ...[
              const SizedBox(width: 30),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: isSelected ? const Color(0xFF345F00) : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildExpandButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IconButton(
        icon: Icon(
          isExpanded ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
          color: Colors.white,
        ),
        onPressed: _toggleSidebar,
      ),
    );
  }

  void _logout(BuildContext context) async {
    bool confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text('Logout'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/login_page', (Route<dynamic> route) => false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:rumini/components/sidebar.dart';
import 'package:rumini/pages(admin)/templates/AnnounceTemp.dart';
import 'package:rumini/pages(admin)/templates/notifTemp.dart';
import 'package:rumini/pages(admin)/templates/schedTemp.dart';

class TemplatesAd extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TemplatesAd({super.key, required this.userData});

  @override
  State<TemplatesAd> createState() => _TemplatesAdState();
}

class _TemplatesAdState extends State<TemplatesAd> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Row(
        children: [
          Sidebar(userData: widget.userData),
          Expanded(
            child: Column(
              children: [
                // 🔹 Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.dashboard_customize_rounded,
                          color: Color(0xFF345F00)),
                      SizedBox(width: 10),
                      Text(
                        "Templates Management",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF345F00),
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔹 Main Content (Grid Layout)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 60, vertical: 40),
                    child: Center(
                      child: isSmallScreen
                          // 🔸 Mobile Layout: 1 column
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildTemplateCard(
                                  icon: Icons.announcement_rounded,
                                  title: "Announcements",
                                  color1: const Color(0xFFFFA726),
                                  color2: const Color(0xFFFFCC80),
                                  onTap: () =>
                                      showAnnounceTemp(context, widget.userData),
                                ),
                                _buildTemplateCard(
                                  icon: Icons.notifications_active_rounded,
                                  title: "Notification Templates",
                                  color1: const Color(0xFF42A5F5),
                                  color2: const Color(0xFF80D6FF),
                                  onTap: () =>
                                      showNotifTemp(context, widget.userData),
                                ),
                                _buildTemplateCard(
                                  icon: Icons.schedule_rounded,
                                  title: "Schedule Templates",
                                  color1: const Color(0xFFAB47BC),
                                  color2: const Color(0xFFCE93D8),
                                  onTap: () => showSchedTemp(context),
                                ),
                              ],
                            )
                          // 🔸 Desktop Layout: 2x2 grid (now only 3 cards)
                          : Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildTemplateCard(
                                      icon: Icons.announcement_rounded,
                                      title: "Reminder Announcements",
                                      color1: const Color(0xFFFFA726),
                                      color2: const Color(0xFFFFCC80),
                                      onTap: () => showAnnounceTemp(
                                          context, widget.userData),
                                    ),
                                    const SizedBox(width: 40),
                                    _buildTemplateCard(
                                      icon: Icons.notifications_active_rounded,
                                      title: "Notification Templates",
                                      color1: const Color(0xFF42A5F5),
                                      color2: const Color(0xFF80D6FF),
                                      onTap: () => showNotifTemp(
                                          context, widget.userData),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildTemplateCard(
                                      icon: Icons.schedule_rounded,
                                      title: "Schedule Templates",
                                      color1: const Color(0xFFAB47BC),
                                      color2: const Color(0xFFCE93D8),
                                      onTap: () => showSchedTemp(context),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Modern Gradient Card Builder
  Widget _buildTemplateCard({
    required IconData icon,
    required String title,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        width: 280,
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1.withOpacity(0.95), color2.withOpacity(0.9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 🔸 Faint background icon
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                icon,
                size: 100,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            // 🔸 Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black26,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

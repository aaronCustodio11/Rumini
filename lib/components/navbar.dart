
import 'package:rumini/pages(user)/appointments/appointment_page.dart';
import 'package:rumini/pages(user)/home/home_page.dart';
import 'package:rumini/pages(user)/moodtracker/moodtracker.dart';
import 'package:rumini/pages(user)/pyshoeduc/psychoeducational.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class Navbar extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int initialIndex;

  const Navbar({super.key, required this.userData, this.initialIndex = 0});

  @override
  NavbarState createState() => NavbarState();
}

class NavbarState extends State<Navbar> {
  late int selectedIndex;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    pageController = PageController(initialPage: selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: pageController,
          children: <Widget>[
            HomePage(userData: widget.userData),
            Moodtracker(userData: widget.userData),
            AppointmentPage(userData: widget.userData),
            Psychoeducational(userData: widget.userData), 
          ],
        ),
        bottomNavigationBar: ConvexAppBar(
          backgroundColor: Colors.white,
          activeColor: Colors.green,
          color: Colors.grey,
          initialActiveIndex: selectedIndex,
          style: TabStyle.react, // Feel free to try different styles!
          items: const [
            TabItem(icon: Icons.home, title: 'Home'),
            TabItem(icon: Icons.favorite, title: 'Mood'),
            TabItem(icon: Icons.calendar_month, title: 'Appointments'),
            TabItem(icon: Icons.psychology, title: 'Psychoedu'),
          ],
          onTap: (int index) {
            setState(() => selectedIndex = index);
            pageController.jumpToPage(index);
          },
        ),
      ),
    );
  }
}



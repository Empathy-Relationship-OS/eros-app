import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/date_preferences_prompts.dart';
import 'package:eros_app/features/matching/presentation/screens/match_screen.dart';
import 'package:eros_app/features/dates/presentation/screens/dates_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/profile_screen.dart';

/// Main Home Screen with bottom navigation bar
/// Allows switching between Match, Dates, and Profile sections
///
/// The first time it appears for a user whose date preferences aren't set, it asks them to set
/// them ([DatePreferencesFirstRunSheet]).
class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // Pages for each tab
  static const List<Widget> _pages = [
    MatchScreen(),
    DatesScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable back navigation (both gesture and button)
      child: DatePreferencesFirstRunSheet(
        child: Scaffold(
          body: _pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            backgroundColor: AppColors.cardBackground,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            type: BottomNavigationBarType.fixed,
            elevation: 8,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Matches',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today),
                label: 'Dates',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

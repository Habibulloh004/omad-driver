import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import '../auth/auth_guard.dart';
import '../delivery/delivery_page.dart';
import '../driver/driver_dashboard.dart';
import '../home/home_page.dart';
import '../notifications/notifications_page.dart';
import '../orders/orders_page.dart';
import '../profile/profile_page.dart';
import '../taxi/taxi_order_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _profileTabIndex = 2;
  int _currentIndex = 0;
  late final List<Widget> _tabs;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomePage(
        key: const PageStorageKey('homeTab'),
        onOrderTaxi: () => _openPage(const TaxiOrderPage()),
        onSendDelivery: () => _openPage(const DeliveryPage()),
        onOpenNotifications: () => _openPage(const NotificationsPage()),
        onRequireLogin: _promptLogin,
      ),
      const OrdersPage(key: PageStorageKey('ordersTab')),
      ProfilePage(
        key: const PageStorageKey('profileTab'),
        onOpenDriverDashboard: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverDashboard()),
          );
        },
      ),
    ];
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      extendBody: true,
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tabs.length,
        onPageChanged: (index) async {
          if (_currentIndex == index) return;
          if (index == _profileTabIndex &&
              !await _promptLoginIfNeeded()) {
            _pageController.jumpToPage(_currentIndex);
            return;
          }
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return _tabs[index];
        },
      ),
      bottomNavigationBar: _FrostedNavBar(
        currentIndex: _currentIndex,
        onChanged: _animateToPage,
        items: [
          _NavItem(icon: Icons.home_rounded, label: strings.tr('home')),
          _NavItem(
            icon: Icons.receipt_long_rounded,
            label: strings.tr('orders'),
          ),
          _NavItem(icon: Icons.person_rounded, label: strings.tr('profile')),
        ],
      ),
    );
  }

  void _animateToPage(int index) async {
    if (_currentIndex == index) return;
    if (index == _profileTabIndex && !await _promptLoginIfNeeded()) {
      return;
    }
    _pageController.jumpToPage(index);
    setState(() => _currentIndex = index);
  }

  Future<bool> _promptLoginIfNeeded() async {
    final state = context.read<AppState>();
    if (state.isAuthenticated) return true;
    return _promptLogin();
  }

  Future<bool> _promptLogin() {
    return ensureLoggedIn(context, showMessage: false);
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _FrostedNavBar extends StatelessWidget {
  const _FrostedNavBar({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundAlpha = isDark ? 0.32 : 0.68;
    final borderAlpha = isDark ? 0.38 : 0.18;
    final highlightColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.pillRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.pillRadius,
            color: theme.colorScheme.surface.withValues(
              alpha: backgroundAlpha,
            ),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(
                alpha: borderAlpha,
              ),
            ),
            boxShadow: AppShadows.soft(
              baseColor: theme.colorScheme.primary,
              isDark: isDark,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              final highlightWidth = itemWidth;
              final highlightLeft = currentIndex * itemWidth;
              final highlightGradient = LinearGradient(
                colors: [highlightColor, theme.colorScheme.secondary],
              );

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedPositioned(
                    duration: AppDurations.short,
                    curve: Curves.easeOut,
                    left: highlightLeft,
                    top: 0,
                    bottom: 0,
                    width: highlightWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppRadii.pillRadius,
                        gradient: highlightGradient,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: items[i],
                            selected: i == currentIndex,
                            onTap: () => onChanged(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseIcon = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.84);
    final baseText = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.82);
    final activeForeground = theme.colorScheme.onPrimary;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
      duration: AppDurations.short,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        final iconColor = Color.lerp(baseIcon, activeForeground, value)!;
        final textColor = Color.lerp(baseText, activeForeground, value)!;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm - 2,
          ),
          decoration: const BoxDecoration(borderRadius: AppRadii.pillRadius),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadii.pillRadius,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: iconColor, size: 24),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

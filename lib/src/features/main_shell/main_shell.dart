import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../localization/localization_ext.dart';
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
  int _currentIndex = 0;
  late final List<Widget> _tabs;
  late final PageController _pageController;
  double _pageValue = 0;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomePage(
        key: const PageStorageKey('homeTab'),
        onOrderTaxi: () => _openPage(const TaxiOrderPage()),
        onSendDelivery: () => _openPage(const DeliveryPage()),
        onOpenNotifications: () => _openPage(const NotificationsPage()),
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
    _pageValue = _currentIndex.toDouble();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
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
        physics: const BouncingScrollPhysics(),
        itemCount: _tabs.length,
        onPageChanged: (index) {
          if (_currentIndex == index) return;
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return _ParallaxPage(
            controller: _pageController,
            index: index,
            child: _tabs[index],
          );
        },
      ),
      bottomNavigationBar: _FrostedNavBar(
        currentIndex: _currentIndex,
        pageValue: _pageValue,
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

  void _onPageChanged() {
    final value = _pageController.hasClients
        ? _pageController.page ?? _currentIndex.toDouble()
        : _currentIndex.toDouble();
    if (value == _pageValue) return;
    setState(() => _pageValue = value);
  }

  void _animateToPage(int index) {
    if (_currentIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: AppDurations.long,
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentIndex = index);
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: AppDurations.long,
        reverseTransitionDuration: AppDurations.medium,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(fade);
          final scale = Tween<double>(begin: 0.95, end: 1).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
      ),
    );
  }
}

class _FrostedNavBar extends StatelessWidget {
  const _FrostedNavBar({
    required this.items,
    required this.currentIndex,
    required this.pageValue,
    required this.onChanged,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final double pageValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundAlpha = isDark ? 0.32 : 0.68;
    final borderAlpha = isDark ? 0.38 : 0.18;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.pillRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: AppDurations.medium,
            curve: Curves.easeInOutCubic,
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
                final indicatorWidth = itemWidth * 0.42;
                final clampedPage = pageValue.clamp(
                  0.0,
                  (items.length - 1).toDouble(),
                );
                final indicatorLeft =
                    clampedPage * itemWidth + (itemWidth - indicatorWidth) / 2;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedPositioned(
                      duration: AppDurations.medium,
                      curve: Curves.easeInOutCubic,
                      left: indicatorLeft,
                      bottom: AppSpacing.xs,
                      width: indicatorWidth,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7367F0), Color(0xFFA29BFE)],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavButton(
                              item: items[i],
                              progress: _selectionProgress(pageValue, i),
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
      ),
    );
  }

  double _selectionProgress(double page, int index) {
    final distance = (page - index).abs();
    if (distance >= 1) {
      return index == currentIndex ? 1 : 0;
    }
    return 1 - distance;
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
    required this.progress,
    required this.onTap,
  });

  final _NavItem item;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final activeBackground = theme.colorScheme.primary.withValues(alpha: 0.18);
    final background = Color.lerp(
      Colors.transparent,
      activeBackground,
      Curves.easeInOutCubic.transform(progress.clamp(0, 1)),
    );
    final iconColor = Color.lerp(
      baseColor,
      theme.colorScheme.onPrimary,
      progress.clamp(0, 1),
    );
    final textColor = Color.lerp(
      theme.colorScheme.onSurfaceVariant,
      theme.colorScheme.onPrimary,
      progress.clamp(0, 1),
    );

    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: Curves.easeInOutCubic,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.rounded,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.rounded,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: iconColor),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParallaxPage extends StatelessWidget {
  const _ParallaxPage({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, widget) {
        final hasClients = controller.hasClients;
        final page = hasClients
            ? controller.page ?? controller.initialPage.toDouble()
            : controller.initialPage.toDouble();
        final delta = (page - index);
        final eased = Curves.easeInOutCubic.transform(
          (1 - delta.abs()).clamp(0.0, 1.0),
        );
        final translateX = -delta * 28;
        final blur = (delta.abs() * 12).clamp(0.0, 12.0);

        return Transform.translate(
          offset: Offset(translateX, 0),
          child: Opacity(
            opacity: eased,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: widget,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

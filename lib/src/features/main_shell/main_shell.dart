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

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<Widget> _tabs;
  late final PageController _pageController;
  late final AnimationController _jumpController;
  late final Animation<double> _jumpFade;
  late final Animation<double> _jumpScale;
  static const AlwaysStoppedAnimation<double> _unitAnimation =
      AlwaysStoppedAnimation<double>(1);
  bool _isDirectJump = false;
  bool _hasJumpedDuringTransition = false;
  int? _pendingJumpIndex;

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
    _jumpController = AnimationController(
      vsync: this,
      duration: AppDurations.medium,
    );
    _jumpFade = _jumpController.drive(
      TweenSequence<double>(
        [
          TweenSequenceItem(
            tween: Tween<double>(begin: 1, end: 0).chain(
              CurveTween(curve: Curves.easeInOutCubic),
            ),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: 1).chain(
              CurveTween(curve: Curves.easeInOutCubic),
            ),
            weight: 50,
          ),
        ],
      ),
    );
    _jumpScale = _jumpController.drive(
      TweenSequence<double>(
        [
          TweenSequenceItem(
            tween: Tween<double>(begin: 1, end: 0.96).chain(
              CurveTween(curve: Curves.easeInOutCubic),
            ),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.96, end: 1).chain(
              CurveTween(curve: Curves.easeOutBack),
            ),
            weight: 50,
          ),
        ],
      ),
    );
    _jumpController.addListener(_handleJumpTick);
    _jumpController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _jumpController.reset();
        if (mounted) {
          setState(() {
            _isDirectJump = false;
          });
        } else {
          _isDirectJump = false;
        }
        _hasJumpedDuringTransition = false;
      }
    });
  }

  @override
  void dispose() {
    _jumpController.removeListener(_handleJumpTick);
    _jumpController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      extendBody: true,
      body: IgnorePointer(
        ignoring: _isDirectJump,
        child: FadeTransition(
          opacity: _isDirectJump ? _jumpFade : _unitAnimation,
          child: ScaleTransition(
            scale: _isDirectJump ? _jumpScale : _unitAnimation,
            child: PageView.builder(
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
          ),
        ),
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

  void _animateToPage(int index) {
    if (_currentIndex == index) return;
    final currentPage = _pageController.hasClients
        ? (_pageController.page ?? _currentIndex.toDouble())
        : _currentIndex.toDouble();
    final isAdjacent = (currentPage - index).abs() <= 1;

    if (isAdjacent) {
      _pageController.animateToPage(
        index,
        duration: AppDurations.long,
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentIndex = index);
      return;
    }

    if (_isDirectJump) {
      _jumpController.stop();
      _jumpController.reset();
      _hasJumpedDuringTransition = false;
    }
    _pendingJumpIndex = index;
    _hasJumpedDuringTransition = false;
    _jumpController.forward(from: 0);
    setState(() {
      _currentIndex = index;
      _isDirectJump = true;
    });
  }

  void _handleJumpTick() {
    if (!_isDirectJump || _pendingJumpIndex == null) return;
    if (_hasJumpedDuringTransition) return;
    if (_jumpController.value < 0.5) return;

    final target = _pendingJumpIndex!;
    _hasJumpedDuringTransition = true;
    _pendingJumpIndex = null;
    _pageController.jumpToPage(target);
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
                final highlightWidth = itemWidth;
                final highlightLeft = currentIndex * itemWidth;
                final highlightGradient = LinearGradient(
                  colors: [highlightColor, theme.colorScheme.secondary],
                );

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedPositioned(
                      duration: AppDurations.medium,
                      curve: Curves.easeInOutCubic,
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
      duration: AppDurations.medium,
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) {
        final iconColor = Color.lerp(baseIcon, activeForeground, value)!;
        final textColor = Color.lerp(baseText, activeForeground, value)!;

        return AnimatedContainer(
          duration: AppDurations.medium,
          curve: Curves.easeInOutCubic,
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

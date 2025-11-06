import 'package:flutter/material.dart';

import '../../localization/localization_ext.dart';
import '../../widgets/gradient_button.dart';

class OrderSentPage extends StatefulWidget {
  const OrderSentPage({
    super.key,
    required this.title,
    required this.message,
    this.orderId,
  });

  final String title;
  final String message;
  final String? orderId;

  @override
  State<OrderSentPage> createState() => _OrderSentPageState();
}

class _OrderSentPageState extends State<OrderSentPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> scale;
  late final Animation<double> opacity;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    scale = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    opacity = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.14),
                      blurRadius: 18,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: FadeTransition(
                  opacity: opacity,
                  child: Icon(
                    Icons.check_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.orderId != null) ...[
              const SizedBox(height: 12),
              Text(
                '${strings.tr('orderId')}: ${widget.orderId}',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 48),
            GradientButton(
              onPressed: () => Navigator.of(context).pop(),
              label: strings.tr('backHome'),
              icon: Icons.home_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../api/auth_api.dart';
import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../common/order_sent_page.dart';

class DriverApplicationPage extends StatefulWidget {
  const DriverApplicationPage({super.key});

  @override
  State<DriverApplicationPage> createState() => _DriverApplicationPageState();
}

class _DriverApplicationPageState extends State<DriverApplicationPage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  final TextEditingController carModelCtrl = TextEditingController();
  final TextEditingController carNumberCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _licenseFile;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    nameCtrl = TextEditingController(text: state.currentUser.fullName);
    phoneCtrl = TextEditingController(text: state.currentUser.phoneNumber);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    carModelCtrl.dispose();
    carNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('driverApplication'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.tr('driverApplicationSubtitle'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: nameCtrl,
                    label: strings.tr('fullName'),
                    prefixIcon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: phoneCtrl,
                    label: strings.tr('phoneNumber'),
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_android_rounded,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: carModelCtrl,
                    label: strings.tr('carModel'),
                    prefixIcon: Icons.directions_car_filled_rounded,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: carNumberCtrl,
                    label: strings.tr('carNumber'),
                    prefixIcon: Icons.confirmation_number_rounded,
                  ),
                  const SizedBox(height: 16),
                  Text(strings.tr('driverLicenseUpload')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: loading ? null : _pickLicense,
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: Text(
                      _licenseFile == null
                          ? strings.tr('uploadPlaceholder')
                          : _licenseFile!.path
                                .split(Platform.pathSeparator)
                                .last,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              onPressed: loading ? null : _submit,
              label: strings.tr('submitApplication'),
              icon: Icons.send_rounded,
              loading: loading,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final strings = context.strings;
    if (carModelCtrl.text.isEmpty || carNumberCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('fillAllFields'))));
      return;
    }

    final licenseFile = _licenseFile;
    if (licenseFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('noImageSelected'))));
      return;
    }

    setState(() => loading = true);
    try {
      await context.read<AppState>().submitDriverApplication(
        fullName: nameCtrl.text,
        carModel: carModelCtrl.text,
        carNumber: carNumberCtrl.text,
        licenseFile: licenseFile,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSentPage(
            title: strings.tr('applicationSentTitle'),
            message: strings.tr('applicationSentDescription'),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.tr('unexpectedError'))));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _pickLicense() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _licenseFile = File(picked.path));
  }
}

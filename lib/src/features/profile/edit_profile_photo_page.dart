import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../api/auth_api.dart';
import '../../core/design_tokens.dart';
import '../../localization/localization_ext.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

class EditProfilePhotoPage extends StatefulWidget {
  const EditProfilePhotoPage({super.key});

  @override
  State<EditProfilePhotoPage> createState() => _EditProfilePhotoPageState();
}

class _EditProfilePhotoPageState extends State<EditProfilePhotoPage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;
  bool _uploading = false;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1500,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _selectedFile = File(picked.path));
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    final strings = context.strings;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.tr('noImageSelected'))),
      );
      return;
    }
    setState(() => _uploading = true);
    final state = context.read<AppState>();
    try {
      await state.uploadProfilePicture(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.tr('photoUpdated'))),
      );
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.tr('unexpectedError'))),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final state = context.watch<AppState>();
    final existingAvatar = state.currentUser.avatarUrl;

    ImageProvider? previewProvider;
    if (_selectedFile != null) {
      previewProvider = FileImage(_selectedFile!);
    } else if (existingAvatar.isNotEmpty) {
      previewProvider = NetworkImage(existingAvatar);
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.tr('changePhoto'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: previewProvider,
                  child: previewProvider == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _selectedFile == null
                    ? strings.tr('noImageSelected')
                    : _selectedFile!.path.split(Platform.pathSeparator).last,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickImage,
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(strings.tr('selectImage')),
              ),
              const SizedBox(height: AppSpacing.lg),
              GradientButton(
                onPressed: _uploading ? null : _upload,
                label: strings.tr('uploadPhoto'),
                icon: _uploading
                    ? null
                    : Icons.cloud_upload_rounded,
                loading: _uploading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

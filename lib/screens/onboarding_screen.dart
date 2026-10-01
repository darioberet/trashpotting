import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../services/media_picker_service.dart';
import '../services/photo_upload_service.dart';
import '../services/username_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../widgets/image_source_bottom_sheet.dart';

/// Flusso di onboarding mostrato una sola volta, alla prima attivazione di
/// un account nuovo (vedi `AppSession.onboardingComplete` / router redirect
/// in `app.dart`). Due step interni gestiti localmente in un `PageView`,
/// stesso approccio di `main_shell.dart` per l'indice delle tab.
class OnboardingScreen extends StatefulWidget {
  OnboardingScreen({
    super.key,
    AuthService? authService,
    UserProfileRepository? userProfileRepository,
    MediaPickerService? mediaPickerService,
    PhotoUploadService? photoUploadService,
    UsernameService? usernameService,
  }) : _authService = authService ?? AuthService(),
       _usernameService = usernameService ?? UsernameService(),
       _userProfileRepository =
           userProfileRepository ?? UserProfileRepository(),
       _mediaPickerService = mediaPickerService ?? MediaPickerService(),
       _photoUploadService = photoUploadService ?? PhotoUploadService();

  final AuthService _authService;
  final UsernameService _usernameService;
  final UserProfileRepository _userProfileRepository;
  final MediaPickerService _mediaPickerService;
  final PhotoUploadService _photoUploadService;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  String? _photoPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingName());
  }

  Future<void> _loadExistingName() async {
    final uid = AppSessionScope.of(context).currentUserId;
    if (uid == null) return;
    try {
      final profile = await widget._userProfileRepository.fetchProfile(uid);
      if (!mounted) return;
      final name = profile?.username?.trim();
      if (name != null && name.isNotEmpty) {
        _nameController.text = name;
      }
    } catch (_) {
      // Best-effort: il nome resta vuoto se il fetch fallisce.
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showImageSourceBottomSheet(context);
    if (source == null) return;
    final path = await widget._mediaPickerService.pickImagePath(source);
    if (path == null || !mounted) return;
    setState(() => _photoPath = path);
  }

  void _goToProfileStep() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    if (_busy) return;
    final session = AppSessionScope.of(context);
    final uid = session.currentUserId;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      String? photoUrl;
      if (_photoPath != null) {
        photoUrl = await widget._photoUploadService.uploadProfilePhoto(
          localPath: _photoPath!,
          ownerId: uid,
        );
      }
      final name = _nameController.text.trim();
      if (photoUrl != null) {
        await widget._authService.updateProfile(photoURL: photoUrl);
      }
      if (name.isNotEmpty) {
        await widget._usernameService.save(uid: uid, username: name);
      }
      // Nome e foto vanno visti subito da Profilo e segnalazioni.
      session.refreshCurrentUser();
      if (name.isNotEmpty) session.setUsername(name);
      await session.markOnboardingComplete();
      if (!mounted) return;
      context.go(AppRoutes.mappa);
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Impossibile completare il profilo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WelcomeStep(onContinue: _goToProfileStep),
          _ProfileSetupStep(
            nameController: _nameController,
            photoPath: _photoPath,
            busy: _busy,
            onPickPhoto: _pickPhoto,
            onFinish: _finish,
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.greenBrand, AppColors.greenDark],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              SvgPicture.asset(
                'assets/icons/logo_leaf_pin.svg',
                width: 72,
                height: 72,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Benvenuto in Trashpotting',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Segnala rifiuti abbandonati, segui la loro pulizia e '
                'scala la classifica dei contributori del tuo territorio.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withAlpha(220),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.greenBrand,
                  ),
                  onPressed: onContinue,
                  child: const Text('Continua'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSetupStep extends StatelessWidget {
  const _ProfileSetupStep({
    required this.nameController,
    required this.photoPath,
    required this.busy,
    required this.onPickPhoto,
    required this.onFinish,
  });

  final TextEditingController nameController;
  final String? photoPath;
  final bool busy;
  final VoidCallback onPickPhoto;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && !kIsWeb;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        children: [
          Text(
            'Completa il tuo profilo',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aggiungi una foto e il tuo nome — puoi farlo anche più tardi, '
            'da Profilo.',
            style: TextStyle(
              fontSize: 13,
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Semantics(
              label: 'Aggiungi foto profilo',
              button: true,
              child: GestureDetector(
                onTap: onPickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.greenLight,
                        image: hasPhoto
                            ? DecorationImage(
                                image: FileImage(File(photoPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: context.palette.cardShadow,
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: !hasPhoto
                          ? const Icon(
                              Icons.person,
                              size: 48,
                              color: AppColors.greenBrand,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.greenBrand,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: busy ? null : onFinish,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Completa'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : onFinish,
            child: const Text('Salta per ora'),
          ),
        ],
      ),
    );
  }
}

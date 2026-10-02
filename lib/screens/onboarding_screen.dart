import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../services/media_picker_service.dart';
import '../services/photo_upload_service.dart';
import '../services/username_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/image_source_bottom_sheet.dart';
import '../theme/app_icons.dart';

/// Colori delle illustrazioni dell'onboarding (assets/onboarding/): lo
/// sfondo coincide con il loro, così le immagini si fondono con la pagina.
abstract final class _OnbColors {
  static const background = Color(0xFFFDFDFB);
  static const navy = Color(0xFF021552);
  static const orange = Color(0xFFFC5022);
  static const text = Color(0xFF4A4F6A);
  static const dotInactive = Color(0xFFE3E1DA);
}

/// Pagina illustrata dell'introduzione.
class _IntroPage {
  const _IntroPage({
    required this.asset,
    required this.title,
    required this.body,
  });

  final String asset;
  final String title;
  final String body;
}

const _introPages = [
  _IntroPage(
    asset: 'assets/onboarding/segnala.svg',
    title: 'Hai visto dei rifiuti?\nSegnalali in 10 secondi',
    body:
        'Una foto, la posizione e il gioco è fatto: la segnalazione compare '
        'sulla mappa per tutti.',
  ),
  _IntroPage(
    asset: 'assets/onboarding/pulisci.svg',
    title: 'Ripuliamo insieme',
    body:
        'Prendi in carico una zona o organizza una pulizia con le persone '
        'vicino a te.',
  ),
  _IntroPage(
    asset: 'assets/onboarding/classifica.svg',
    title: 'Ogni gesto conta\n(e fa punti)',
    body:
        '1 punto per ogni segnalazione, 2 per ogni pulizia completata. '
        'Scala la classifica del tuo territorio!',
  ),
];

/// Indici delle pagine fisse dopo l'introduzione.
const _locationPage = 3;
const _profilePage = 4;
const _pageCount = 5;

/// Onboarding mostrato una sola volta agli account nuovi (vedi
/// `AppSession.onboardingComplete` e il redirect in `app.dart`):
/// tre pagine di presentazione, la richiesta motivata del permesso di
/// posizione e il profilo.
///
/// Usa sempre il tema chiaro: le illustrazioni sono disegnate su fondo chiaro.
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
  int _page = 0;
  String? _photoPath;
  bool _busy = false;
  bool _requestingLocation = false;

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

  void _goTo(int page) {
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() => _goTo(_page + 1);

  /// Spiega prima perché serve la posizione, poi mostra il popup di Android:
  /// chiederlo "a freddo" fa rifiutare il permesso molto più spesso.
  Future<void> _requestLocation() async {
    if (_requestingLocation) return;
    setState(() => _requestingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
      }
    } catch (_) {
      // Se qualcosa va storto si prosegue: dopo l'onboarding la schermata
      // "Attiva la posizione" (LocationGate) chiede di nuovo.
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
    if (mounted) _goTo(_profilePage);
  }

  Future<void> _pickPhoto() async {
    final source = await showImageSourceBottomSheet(context);
    if (source == null) return;
    final path = await widget._mediaPickerService.pickImagePath(source);
    if (path == null || !mounted) return;
    setState(() => _photoPath = path);
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
    final isIntro = _page < _locationPage;

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: _OnbColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // "Salta" porta al permesso di posizione, non oltre: la
              // posizione serve comunque per usare l'app.
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    opacity: isIntro ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: isIntro ? () => _goTo(_locationPage) : null,
                      style: TextButton.styleFrom(
                        foregroundColor: _OnbColors.text,
                      ),
                      child: const Text('Salta'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  // Avanti solo con i pulsanti dal permesso in poi: lo swipe
                  // salterebbe la richiesta di posizione.
                  physics: _page >= _locationPage
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (p) => setState(() => _page = p),
                  children: [
                    for (final page in _introPages)
                      _IllustratedPage(
                        illustration: SvgPicture.asset(page.asset),
                        title: page.title,
                        body: page.body,
                      ),
                    _IllustratedPage(
                      illustration: Image.asset(
                        'assets/onboarding/posizione.png',
                      ),
                      title: 'Ci serve la tua posizione',
                      body:
                          'Per mostrarti i rifiuti vicino a te e registrare '
                          'dove si trovano quelli che segnali. La usiamo solo '
                          'mentre usi l\'app, e gli altri utenti non vedono '
                          'dove sei.',
                    ),
                    _ProfilePage(
                      nameController: _nameController,
                      photoPath: _photoPath,
                      busy: _busy,
                      onPickPhoto: _pickPhoto,
                    ),
                  ],
                ),
              ),
              _PageDots(count: _pageCount, current: _page),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _BottomActions(
                  page: _page,
                  busy: _busy,
                  requestingLocation: _requestingLocation,
                  onNext: _next,
                  onRequestLocation: _requestLocation,
                  onFinish: _finish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustratedPage extends StatelessWidget {
  const _IllustratedPage({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final Widget illustration;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Su schermi bassi l'illustrazione si riduce, il testo resta intero.
        final size = (constraints.maxHeight * 0.58).clamp(160.0, 360.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(dimension: size, child: illustration),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: _OnbColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: _OnbColors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.nameController,
    required this.photoPath,
    required this.busy,
    required this.onPickPhoto,
  });

  final TextEditingController nameController;
  final String? photoPath;
  final bool busy;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && !kIsWeb;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Aggiungi foto profilo',
                button: true,
                child: GestureDetector(
                  onTap: busy ? null : onPickPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.greenLight,
                          border: Border.all(
                            color: _OnbColors.orange.withAlpha(90),
                            width: 3,
                          ),
                          image: hasPhoto
                              ? DecorationImage(
                                  image: FileImage(File(photoPath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: !hasPhoto
                            ? const Icon(
                                AppIcons.userFilled,
                                size: 56,
                                color: AppColors.greenBrand,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: _OnbColors.orange,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 2),
                            ),
                          ),
                          child: const Icon(
                            AppIcons.cameraFilled,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Come ti chiamiamo?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _OnbColors.navy,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Scegli un username e, se vuoi, una foto. È quello che vedranno '
                'gli altri in classifica. Puoi cambiarli quando vuoi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: _OnbColors.text,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                enabled: !busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(AppIcons.username),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puntini di avanzamento: quello della pagina corrente si allunga.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pagina ${current + 1} di $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == current ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current
                    ? _OnbColors.orange
                    : _OnbColors.dotInactive,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.page,
    required this.busy,
    required this.requestingLocation,
    required this.onNext,
    required this.onRequestLocation,
    required this.onFinish,
  });

  final int page;
  final bool busy;
  final bool requestingLocation;
  final VoidCallback onNext;
  final VoidCallback onRequestLocation;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final (label, onPressed, loading) = switch (page) {
      _locationPage => (
        'Consenti la posizione',
        requestingLocation ? null : onRequestLocation,
        requestingLocation,
      ),
      _profilePage => ('Inizia', busy ? null : onFinish, busy),
      _ => ('Avanti', onNext, false),
    };

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: onPressed,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label, style: const TextStyle(fontSize: 16)),
          ),
        ),
        // Seconda azione solo sull'ultima pagina, a parità di altezza
        // per non far "saltare" il layout tra una pagina e l'altra.
        SizedBox(
          height: 44,
          child: page == _profilePage
              ? TextButton(
                  onPressed: busy ? null : onFinish,
                  style: TextButton.styleFrom(
                    foregroundColor: _OnbColors.text,
                  ),
                  child: const Text('Salta per ora'),
                )
              : null,
        ),
      ],
    );
  }
}

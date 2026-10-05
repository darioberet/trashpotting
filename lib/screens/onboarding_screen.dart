import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../repositories/leaderboard_repository.dart'
    show pointsPerCleanup, pointsPerReport;
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../services/media_picker_service.dart';
import '../services/photo_upload_service.dart';
import '../services/username_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/illustration.dart';
import '../widgets/image_source_bottom_sheet.dart';
import '../widgets/tab_header.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_icons.dart';

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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AppColors.bgAlt,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        AnimatedOpacity(
                          opacity: _page > 0 ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: IgnorePointer(
                            ignoring: _page == 0,
                            child: HeaderCircleButton(
                              icon: AppIcons.back,
                              tooltip: 'Indietro',
                              onPressed: () => _goTo(_page - 1),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // "Salta" porta al permesso di posizione, non oltre:
                        // la posizione serve comunque per usare l'app.
                        AnimatedOpacity(
                          opacity: isIntro ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: TextButton(
                            onPressed: isIntro
                                ? () => _goTo(_locationPage)
                                : null,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.greenDark,
                            ),
                            child: const Text('Salta'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    // Avanti solo con i pulsanti dal permesso in poi: lo
                    // swipe salterebbe la richiesta di posizione.
                    physics: _page >= _locationPage
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [
                      for (final (i, page) in _introPages.indexed)
                        _IllustratedPage(
                          illustration: SvgPicture.asset(page.asset),
                          title: page.title,
                          body: page.body,
                          dots: _PageDots(count: _pageCount, current: i),
                          extra: switch (i) {
                            1 => const _CleanupModes(),
                            2 => const _PointsTiles(),
                            _ => null,
                          },
                        ),
                      _IllustratedPage(
                        illustration: const MultiplyImage(
                          asset: 'assets/onboarding/posizione.png',
                        ),
                        title: 'Ci serve la tua posizione',
                        body:
                            'Per mostrarti i rifiuti vicino a te e registrare '
                            'dove si trovano quelli che segnali. La usiamo '
                            'solo mentre usi l\'app, e gli altri utenti non '
                            'vedono dove sei.',
                        dots: const _PageDots(
                          count: _pageCount,
                          current: _locationPage,
                        ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
      ),
    );
  }
}

class _IllustratedPage extends StatelessWidget {
  const _IllustratedPage({
    required this.illustration,
    required this.title,
    required this.body,
    required this.dots,
    this.extra,
  });

  final Widget illustration;
  final String title;
  final String body;
  final Widget dots;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Su schermi bassi l'illustrazione si riduce, il testo resta intero.
        final size = math.min(
          (constraints.maxHeight * 0.5).clamp(150.0, 320.0),
          constraints.maxWidth - 48,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IllustrationCircle(size: size, child: illustration),
                const SizedBox(height: 20),
                dots,
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 34 / 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 22 / 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (extra != null) ...[const SizedBox(height: 18), extra!],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Me ne occupo io" e "Evento di gruppo": i due modi di pulire.
class _CleanupModes extends StatelessWidget {
  const _CleanupModes();

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, Color bg, Color fg) => Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        chip(
          AppIcons.hand,
          'Me ne occupo io',
          AppColors.greenLight,
          AppColors.greenDark,
        ),
        chip(
          AppIcons.calendar,
          'Evento di gruppo',
          AppColors.purpleLight,
          AppColors.purpleDark,
        ),
      ],
    );
  }
}

/// "+1 segnalazione" e "+2 pulizia".
class _PointsTiles extends StatelessWidget {
  const _PointsTiles();

  @override
  Widget build(BuildContext context) {
    Widget tile(int points, String label, {required bool strong}) => Container(
      constraints: const BoxConstraints(minWidth: 70),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: strong ? AppColors.yellow : AppColors.yellowLight,
        borderRadius: BorderRadius.circular(18),
        boxShadow: strong
            ? const [
                BoxShadow(color: AppColors.yellowEdge, offset: Offset(0, 4)),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+$points',
            style: TextStyle(
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: strong ? AppColors.onYellow : AppColors.yellowText,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: strong ? AppColors.onYellow : AppColors.yellowText,
            ),
          ),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile(pointsPerReport, 'segnalazione', strong: false),
        const SizedBox(width: 10),
        tile(pointsPerCleanup, 'pulizia', strong: true),
      ],
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
    final uid = AppSessionScope.of(context).currentUserId ?? 'nuovo';

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: hasPhoto
                    ? 'Cambia foto profilo'
                    : 'Aggiungi foto profilo',
                button: true,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: busy ? null : onPickPhoto,
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.greenLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Center(
                          child: ListenableBuilder(
                            listenable: nameController,
                            builder: (context, _) => Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.white,
                                    spreadRadius: 6,
                                  ),
                                ],
                                image: hasPhoto
                                    ? DecorationImage(
                                        image: FileImage(File(photoPath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: hasPhoto
                                  ? null
                                  : UserAvatar(
                                      name: nameController.text.trim().isEmpty
                                          ? '?'
                                          : nameController.text,
                                      seed: uid,
                                      size: 120,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.yellow,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.bgAlt,
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.yellowEdge,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              AppIcons.cameraFilled,
                              size: 20,
                              color: AppColors.onYellow,
                            ),
                          ),
                        ),
                        const Positioned(
                          right: -2,
                          top: 4,
                          child: Icon(
                            AppIcons.starFilled,
                            size: 26,
                            color: AppColors.yellow,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 22,
                          child: Transform.rotate(
                            angle: -0.6,
                            child: const Icon(
                              AppIcons.leaf,
                              size: 22,
                              color: Color(0xFF8ED9C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _PageDots(count: _pageCount, current: _profilePage),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: const Text(
                  'Come ti chiamiamo?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    height: 34 / 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Scegli un username e, se vuoi, una foto. È quello che '
                'vedranno gli altri in classifica. Puoi cambiarli quando '
                'vuoi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 22 / 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Username',
                icon: AppIcons.username,
                controller: nameController,
                hintText: 'Es. Carletto',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              // Anteprima della riga in classifica.
              ListenableBuilder(
                listenable: nameController,
                builder: (context, _) {
                  final name = nameController.text.trim();
                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.mintBorder,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'In classifica',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDisabled,
                          ),
                        ),
                        const SizedBox(width: 12),
                        UserAvatar(
                          name: name.isEmpty ? '?' : name,
                          seed: uid,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Utente' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '0',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.greenBrand,
                                ),
                              ),
                              TextSpan(
                                text: ' pt',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDisabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puntini di avanzamento: pagine fatte verdi, quella corrente una pillola
/// gialla, le successive verde chiaro.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pagina ${current + 1} di $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current
                    ? AppColors.yellow
                    : i < current
                    ? AppColors.greenBrand
                    : AppColors.mintBorder,
                borderRadius: BorderRadius.circular(4),
                boxShadow: i == current
                    ? const [
                        BoxShadow(
                          color: AppColors.yellowEdge,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
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
    final (label, icon, onPressed, loading) = switch (page) {
      _locationPage => (
        'Consenti la posizione',
        AppIcons.place,
        onRequestLocation,
        requestingLocation,
      ),
      _profilePage => ('Inizia', AppIcons.arrowRight, onFinish, busy),
      _ => ('Avanti', AppIcons.arrowRight, onNext, false),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          label: label,
          icon: icon,
          loading: loading,
          onPressed: onPressed,
        ),
        // Seconda azione solo sull'ultima pagina, a parità di altezza per
        // non far "saltare" il layout tra una pagina e l'altra.
        SizedBox(
          height: 44,
          child: page == _profilePage
              ? TextButton(
                  onPressed: busy ? null : onFinish,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.greenDark,
                  ),
                  child: const Text('Salta per ora'),
                )
              : null,
        ),
      ],
    );
  }
}

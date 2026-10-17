part of '../report_detail_screen.dart';

/// Foto in testa al dettaglio, a tutta larghezza sotto la status bar. Se la
/// zona è stata ripulita si scorre tra "Prima" e "Dopo" con il selettore.
class _PhotoHeader extends StatefulWidget {
  const _PhotoHeader({required this.report, required this.topInset});

  static const height = 330.0;

  final TrashpotReport report;
  final double topInset;

  @override
  State<_PhotoHeader> createState() => _PhotoHeaderState();
}

class _PhotoHeaderState extends State<_PhotoHeader> {
  final _controller = PageController();
  int _page = 0;

  List<({String label, String url, DateTime? date})> get _photos => [
    if (widget.report.photoUrl != null)
      (
        label: 'Prima',
        url: widget.report.photoUrl!,
        date: widget.report.createdAt,
      ),
    if (widget.report.cleanupPhotoUrl != null)
      (
        label: 'Dopo',
        url: widget.report.cleanupPhotoUrl!,
        date: widget.report.cleanedAt,
      ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final (:bg, :fg) = AppColors.statusChip(widget.report.status);
    // Le etichette servono solo se c'è la foto "Dopo".
    final beforeAfter = widget.report.cleanupPhotoUrl != null;
    final current = photos.isEmpty
        ? null
        : photos[_page.clamp(0, photos.length - 1)];

    return SizedBox(
      height: _PhotoHeader.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            ColoredBox(
              color: bg,
              child: Icon(
                AppIcons.forWasteType(widget.report.typeLabel),
                size: 72,
                color: fg.withAlpha(120),
              ),
            )
          else
            PageView(
              controller: _controller,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                for (final photo in photos)
                  GestureDetector(
                    onTap: () => _openPhotoFullscreen(context, photo.url),
                    child: _HeaderImage(url: photo.url),
                  ),
              ],
            ),
          // Sfumature scure in alto (pulsanti, status bar) e in basso
          // (selettore, puntini).
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x7310231D), Color(0x0010231D)],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0010231D), Color(0x7310231D)],
                  ),
                ),
              ),
            ),
          ),
          if (beforeAfter && current != null) ...[
            Positioned(
              left: 16,
              top: widget.topInset + 72,
              child: IgnorePointer(
                child: _PhotoCaption(
                  text: current.date == null
                      ? current.label
                      : '${current.label}, ${shortDateLabel(current.date!)}',
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: _BeforeAfterToggle(
                  labels: [for (final p in photos) p.label],
                  selected: _page,
                  onSelected: (i) => _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
            ),
          ] else if (photos.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _page ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Colors.white
                              : Colors.white.withAlpha(140),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoCaption extends StatelessWidget {
  const _PhotoCaption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withAlpha(140),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: CachedNetworkImageProvider(url),
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFF3A3A36),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      },
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFF3A3A36),
        child: Center(
          child: Icon(AppIcons.imageBroken, size: 40, color: Colors.white54),
        ),
      ),
    );
  }
}

/// Selettore "Prima | Dopo" sopra la foto: colori fissi perché sta sempre
/// su un'immagine, in qualsiasi tema.
class _BeforeAfterToggle extends StatelessWidget {
  const _BeforeAfterToggle({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withAlpha(140),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Semantics(
              button: true,
              selected: i == selected,
              label: 'Foto ${labels[i]}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 40,
                  constraints: const BoxConstraints(minWidth: 84),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: i == selected ? AppColors.greenDark : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _openPhotoFullscreen(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullscreenPhotoPage(imageUrl: imageUrl),
    ),
  );
}

class _FullscreenPhotoPage extends StatelessWidget {
  const _FullscreenPhotoPage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image(
            image: CachedNetworkImageProvider(imageUrl),
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text(
                'Immagine non disponibile',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

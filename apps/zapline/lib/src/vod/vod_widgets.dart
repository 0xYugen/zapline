import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import 'vod_detail_screens.dart';

/// A film or a series, as cards and rows show them.
class VodTitle {
  const VodTitle.movie(Movie this.movie) : show = null;
  const VodTitle.show(Show this.show) : movie = null;

  final Movie? movie;
  final Show? show;

  bool get isMovie => movie != null;

  String get name => cleanTitle(movie != null ? movie!.name : show!.name);

  Uri? get poster => movie != null ? movie!.posterUrl : show!.coverUrl;

  String? get category => movie != null ? movie!.category : show!.category;

  double? get rating => movie != null ? movie!.rating : show!.rating;

  int? get year => movie != null
      ? movie!.year
      : int.tryParse(
          RegExp(r'(19|20)\d\d').firstMatch(show!.releaseDate ?? '')?[0] ?? '',
        );

  /// The key positions and My list are stored under.
  String get key =>
      movie != null ? VodCatalog.movieKey(movie!) : VodCatalog.showKey(show!);
}

/// "IT - Title (2019)" → "Title": providers prefix the country and append
/// the year, which the card shows apart.
String cleanTitle(String name) {
  var s = name.trim();
  s = s.replaceFirst(RegExp(r'^[A-Z]{2,3}\s*[-:|]\s+'), '');
  s = s.replaceFirst(RegExp(r'\s*[\(\[]?(19|20)\d\d[\)\]]?\s*$'), '');
  s = s.replaceFirst(RegExp(r'\s*-\s*$'), '');
  return s.isEmpty ? name.trim() : s;
}

/// "2019 · Drama · ★ 7.4", leaving out what's unknown.
String titleMeta(VodTitle t, {String? extra}) => [
  if (t.year != null) '${t.year}',
  ?extra,
  if (t.rating != null && t.rating! > 0) '★ ${t.rating!.toStringAsFixed(1)}',
].join(' · ');

void openTitle(BuildContext context, AppState state, VodTitle t) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => t.isMovie
            ? MovieDetailScreen(state: state, movie: t.movie!)
            : ShowDetailScreen(state: state, show: t.show!),
      ),
    );

/// A poster image filling its box, or the title on a tinted card when
/// there is none or it fails to load.
class Poster extends StatelessWidget {
  const Poster({super.key, required this.url, required this.title});

  final Uri? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final fallback = _TitleCard(title: title);
    final u = url;
    if (u == null || !u.hasScheme) return fallback;
    return LayoutBuilder(
      builder: (context, box) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final w = box.maxWidth.isFinite ? box.maxWidth : 160.0;
        return Image(
          image: ResizeImage(
            CachedLogo(u.toString()),
            width: (w * dpr).round(),
            policy: ResizeImagePolicy.fit,
          ),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
          frameBuilder: (_, child, frame, sync) =>
              sync || frame != null ? child : fallback,
        );
      },
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    // A stable hue per title so the wall of cards isn't uniform.
    final hue = (title.hashCode % 360).abs().toDouble();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.35, 0.24).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.30, 0.14).toColor(),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// A blurred, darkened picture behind headers, fading into the page.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.url, this.blur = false});

  final Uri? url;

  /// Posters are portrait and low-res stretched wide; blurring hides it.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final u = url;
    Widget picture = u == null || !u.hasScheme
        ? const ColoredBox(color: ZaplineColors.surface)
        : Image(
            // Decoded small: a full 4K backdrop is tens of megabytes, and
            // blurred it needs far less.
            image: ResizeImage(
              CachedLogo(u.toString()),
              width: blur ? 360 : 1280,
              policy: ResizeImagePolicy.fit,
            ),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: ZaplineColors.surface),
          );
    if (blur) {
      picture = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: picture,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(child: picture),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.45, 1],
              colors: [
                Color(0x66000000),
                Color(0x330B0E13),
                ZaplineColors.ground,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A poster with its title underneath and, once started, a progress bar.
class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.onTap,
    this.width = PosterCard.defaultWidth,
    this.progress,
    this.caption,
  });

  static const defaultWidth = 116.0;

  /// Poster height plus two lines of caption.
  static double heightFor(double width) => width * 1.5 + 44;

  final VodTitle title;
  final VoidCallback onTap;
  final double width;
  final double? progress;

  /// Replaces the year/rating line ("S2·E5" for a series to resume).
  final String? caption;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final progress = widget.progress;
    final meta = widget.caption ?? titleMeta(title);
    return SizedBox(
      width: widget.width,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (f) {
          setState(() => _focused = f);
          if (f) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 150),
            );
          }
        },
        focusColor: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focused
                      ? ZaplineColors.focusBorder
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Poster(url: title.poster, title: title.name),
                      if (progress case final p?)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: LinearProgressIndicator(
                            value: p,
                            minHeight: 4,
                            color: ZaplineColors.focus,
                            backgroundColor: const Color(0x99000000),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            if (meta.isNotEmpty)
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ZaplineColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled, horizontally scrolling row of posters.
class VodRow extends StatelessWidget {
  const VodRow({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
    this.cardWidth = PosterCard.defaultWidth,
  });

  final String title;
  final int itemCount;
  final Widget Function(BuildContext context, int i) itemBuilder;
  final VoidCallback? onSeeAll;
  final double cardWidth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: ZaplineColors.focus,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(context.l10n.seeAll),
                ),
            ],
          ),
        ),
        SizedBox(
          height: PosterCard.heightFor(cardWidth),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    ),
  );
}

/// Posters in a grid that fills the width.
class PosterGrid extends StatelessWidget {
  const PosterGrid({
    super.key,
    required this.state,
    required this.titles,
    this.controller,
  });

  final AppState state;
  final List<VodTitle> titles;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 10.0;
      const pad = 16.0;
      final columns = ((box.maxWidth - 2 * pad + gap) / (110 + gap))
          .floor()
          .clamp(3, 10);
      final w = (box.maxWidth - 2 * pad - gap * (columns - 1)) / columns;
      return GridView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(pad, 12, pad, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 14,
          crossAxisSpacing: gap,
          mainAxisExtent: PosterCard.heightFor(w),
        ),
        itemCount: titles.length,
        itemBuilder: (context, i) => PosterCard(
          title: titles[i],
          width: w,
          onTap: () => openTitle(context, state, titles[i]),
        ),
      );
    },
  );
}

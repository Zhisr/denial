part of 'desktop_system_bar.dart';

/// Media ticker status module.
///
/// Top-level assembly container for the media ticker card. It owns coordinate
/// alignment and state distribution, and composes [_OrbitalDiscGlyph],
/// [_MaskedLyricsTicker] and [_LuminescentText]. The system bar supplies the
/// shared [_SystemBarCard] shell (wallpaper accent + frosted glass) around it.
class _MyMediaStatusModule extends ConsumerStatefulWidget {
  const _MyMediaStatusModule({
    required this.accent,
    required this.side,
    super.key,
  });

  final WallpaperAccent accent;
  final SystemBarSide side;

  @override
  ConsumerState<_MyMediaStatusModule> createState() =>
      _MyMediaStatusModuleState();
}

class _MyMediaStatusModuleState extends ConsumerState<_MyMediaStatusModule> {
  @override
  Widget build(BuildContext context) {
    final accent = context.shellTheme.accent;
    final playback = ref.watch(mediaPlaybackProvider).value;
    final playing = playback?.playing ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OrbitalDiscGlyph(accent: accent, size: 20, playing: playing),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: _MaskedLyricsTicker(
            lines: _mediaTickerLines(playback, context.l10n.mediaNowPlaying),
            playing: playing,
            style: ShellText.base.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              // Bar-text convention: a tight line box with even leading keeps
              // the glyphs optically centred instead of low in the
              // font's ascent/descent box.
              height: -0.15,
              leadingDistribution: TextLeadingDistribution.even,
            ),
            color: const Color.fromARGB(255, 230, 226, 222),
            edgeFade: 0.4,
          ),
        ),
      ],
    );
  }
}

/// The rotating media ticker lines: title, then artists, then album. Falls back
/// to [fallback] when nothing is available.
List<String> _mediaTickerLines(MprisPlaybackState? playback, String fallback) {
  if (playback == null || !playback.available) {
    return <String>[fallback];
  }
  final lines = <String>[
    if (playback.title.isNotEmpty) playback.title,
    if (playback.artists.isNotEmpty) playback.artists.join(', '),
    if (playback.album.isNotEmpty) playback.album,
  ];
  return lines.isEmpty ? <String>[fallback] : lines;
}

/// Dynamically rotating concentric-ring / orbital decoration glyph.
class _OrbitalDiscGlyph extends StatefulWidget {
  const _OrbitalDiscGlyph({
    required this.accent,
    this.size = 24,
    this.playing = true,
    super.key,
  });

  final Color accent;
  final double size;

  /// Whether the rings orbit. False freezes them at the current phase.
  final bool playing;

  @override
  State<_OrbitalDiscGlyph> createState() => _OrbitalDiscGlyphState();
}

class _OrbitalDiscGlyphState extends State<_OrbitalDiscGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: Motion.orbitalDiscSpin);
    if (widget.playing) {
      _spin.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _OrbitalDiscGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) {
      return;
    }
    if (widget.playing) {
      _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Widget _disc(double progress) {
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _OrbitalDiscPainter(
        accent: widget.accent,
        progress: progress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return RepaintBoundary(child: _disc(0.0));
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) => _disc(_spin.value),
      ),
    );
  }
}

/// Backing painter for [_OrbitalDiscGlyph].
///
/// Draws one centred reference circle, then three concentric orbital arcs.
/// Each arc spans a quarter turn and orbits the centre at its own angular
/// velocity from [ringSpeeds].
class _OrbitalDiscPainter extends CustomPainter {
  const _OrbitalDiscPainter({
    required this.accent,
    required this.progress,
    this.ringSpeeds = const <double>[1, -1, 2],
    this.strokeWidth = 1.25,
  });

  final Color accent;

  /// Rotation phase in `[0, 1]`.
  final double progress;

  /// Angular velocity of each ring, innermost first, in full revolutions per
  /// [progress] cycle. Keep the values whole numbers so a repeating controller
  /// loops seamlessly. Positive turns clockwise, negative counter-clockwise.
  final List<double> ringSpeeds;

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    if (radius <= 0) {
      return;
    }

    // 1. The centred reference circle.
    canvas.drawCircle(
      center,
      radius * 17 / 80,
      Paint()
        ..color = accent.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.5,
    );

    // 2. Three concentric orbital arcs, each orbiting the centre at its own
    //    angular velocity.
    const baseAngle = -math.pi / 4;
    const sweepAngle = math.pi / 2; // ends at +pi / 4
    final ringPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.5
      ..strokeCap = StrokeCap.round;
    final radii = <double>[radius / 2, radius * 3 / 4, radius];
    for (var index = 0; index < radii.length; index += 1) {
      final speed = ringSpeeds[index % ringSpeeds.length];
      final angle = baseAngle + 2 * math.pi * progress * speed;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radii[index]),
        angle,
        sweepAngle,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitalDiscPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.progress != progress ||
      !listEquals(oldDelegate.ringSpeeds, ringSpeeds) ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// One layered-stroke glow pass: stroke width and peak alpha.
typedef _StarMediaGlowLayer = ({double width, double alpha});

/// Outermost (widest, faintest) first, so the solid fill draws last on top.
const List<_StarMediaGlowLayer> _starMediaGlowLayers = <_StarMediaGlowLayer>[
  (width: 6.0, alpha: 0.07),
  (width: 3.5, alpha: 0.13),
  (width: 1.6, alpha: 0.24),
];

/// Smoothstep easing over the unit interval.
double _smoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Alpha at [t] (0..1 across the text box) that ramps down to zero over the
/// trailing [fade] of the width along a smoothstep curve, staying at one
/// elsewhere. Only the right edge fades.
double _edgeFadeAlpha(double t, double fade) {
  if (fade <= 0) {
    return 1;
  }
  if (t > 1 - fade) {
    return _smoothstep((1 - t) / fade);
  }
  return 1;
}

/// Horizontal shader that fades [color] to transparent across the trailing
/// [fade] of [bounds] following the smoothstep ramp.
///
/// It is applied directly as a glyph fill shader, so the edge fade costs no
/// save layer.
Shader _edgeFadeShader({
  required Rect bounds,
  required Color color,
  required double fade,
  double peakAlpha = 1,
  int samples = 6,
}) {
  final stops = <double>[];
  final colors = <Color>[];
  for (var index = 0; index <= samples; index += 1) {
    final t = index / samples;
    stops.add(t);
    colors.add(color.withValues(alpha: peakAlpha * _edgeFadeAlpha(t, fade)));
  }
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: colors,
    stops: stops,
  ).createShader(bounds);
}

/// Masked lyrics wrapper with a smoothstep edge fade and rotating lines.
class _MaskedLyricsTicker extends StatefulWidget {
  const _MaskedLyricsTicker({
    required this.lines,
    required this.style,
    required this.color,
    this.glowColor,
    this.playing = true,
    this.edgeFade = 0.01,
    this.interval = Motion.lyricsRotation,
    super.key,
  });

  /// Lines to rotate through, in order.
  final List<String> lines;

  /// Base text metrics. Must not carry a [TextStyle.color] or
  /// [TextStyle.foreground]; both are supplied by [_LuminescentText].
  final TextStyle style;

  final Color color;

  /// Glow tint. Defaults to [color].
  final Color? glowColor;

  /// Whether the ticker advances. Paused keeps the current line on screen.
  final bool playing;

  /// Fraction of the width over which the trailing (right) edge fades to
  /// transparent.
  final double edgeFade;

  /// How long each line stays before cross-fading to the next.
  final Duration interval;

  @override
  State<_MaskedLyricsTicker> createState() => _MaskedLyricsTickerState();
}

class _MaskedLyricsTickerState extends State<_MaskedLyricsTicker> {
  var _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _MaskedLyricsTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final linesChanged = !listEquals(oldWidget.lines, widget.lines);
    if (linesChanged) {
      _index = 0;
    }
    if (linesChanged ||
        oldWidget.playing != widget.playing ||
        oldWidget.interval != widget.interval) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!widget.playing || widget.lines.length < 2) {
      return;
    }
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) {
        return;
      }
      setState(() => _index = (_index + 1) % widget.lines.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    final text = lines.isEmpty ? '' : lines[_index % lines.length];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => RepaintBoundary(
        child: AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : Motion.lyricsCrossFade,
          switchInCurve: Motion.standard,
          switchOutCurve: Motion.standard,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              ...previous,
              ?current,
            ],
          ),
          child: _LuminescentText(
            key: ValueKey<String>(text),
            text: text,
            style: widget.style,
            color: widget.color,
            glowColor: widget.glowColor,
            edgeFade: widget.edgeFade,
            maxWidth: constraints.maxWidth,
          ),
        ),
      ),
    );
  }
}

/// Text glow layer drawn from layered stroke passes.
///
/// The stacked, widening, fading strokes approximate a Gaussian halo without a
/// mask filter, and the optional smoothstep edge fade is applied as a glyph
/// fill shader without a save layer, so an enclosing [RepaintBoundary] can
/// cache the whole element between lyric changes.
class _LuminescentText extends StatefulWidget {
  const _LuminescentText({
    required this.text,
    required this.style,
    required this.color,
    this.glowColor,
    this.edgeFade = 0,
    this.maxWidth = double.infinity,
    this.glowLayers = _starMediaGlowLayers,
    super.key,
  });

  final String text;

  /// Base text metrics. Must not carry a [TextStyle.color] or
  /// [TextStyle.foreground]; both are supplied here.
  final TextStyle style;

  final Color color;

  /// Glow tint. Defaults to [color].
  final Color? glowColor;

  /// Fraction of the text width over which the trailing (right) edge fades to
  /// transparent.
  final double edgeFade;

  final double maxWidth;

  final List<_StarMediaGlowLayer> glowLayers;

  @override
  State<_LuminescentText> createState() => _LuminescentTextState();
}

class _LuminescentTextState extends State<_LuminescentText> {
  List<TextPainter> _glowPainters = const <TextPainter>[];
  TextPainter? _fillPainter;
  Size _size = Size.zero;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _layout();
  }

  @override
  void didUpdateWidget(covariant _LuminescentText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.color != widget.color ||
        oldWidget.glowColor != widget.glowColor ||
        oldWidget.edgeFade != widget.edgeFade ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.glowLayers != widget.glowLayers) {
      _layout();
    }
  }

  @override
  void dispose() {
    _disposePainters();
    super.dispose();
  }

  void _disposePainters() {
    for (final painter in _glowPainters) {
      painter.dispose();
    }
    _fillPainter?.dispose();
  }

  TextPainter _newPainter(TextStyle style) {
    return TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
  }

  void _layout() {
    // Glyph metrics are independent of the paint, so a single layout gives the
    // text box that the edge fade shader spans.
    final probe = _newPainter(widget.style.copyWith(color: widget.color))
      ..layout(maxWidth: widget.maxWidth);
    final textSize = probe.size;
    probe.dispose();
    // Span the edge fade across the whole allotted width so every rotating
    // line fades at the same container edges.
    final size = widget.maxWidth.isFinite
        ? Size(widget.maxWidth, textSize.height)
        : textSize;
    _size = size;
    final bounds = Offset.zero & size;

    _disposePainters();

    final fillStyle = widget.edgeFade > 0
        ? widget.style.copyWith(
            foreground: Paint()
              ..shader = _edgeFadeShader(
                bounds: bounds,
                color: widget.color,
                fade: widget.edgeFade,
              ),
          )
        : widget.style.copyWith(color: widget.color);
    _fillPainter = _newPainter(fillStyle)..layout(maxWidth: widget.maxWidth);

    final glowColor = widget.glowColor ?? widget.color;
    _glowPainters = <TextPainter>[
      for (final layer in widget.glowLayers)
        _newPainter(
          widget.style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = layer.width
              ..strokeJoin = StrokeJoin.round
              ..shader = _edgeFadeShader(
                bounds: bounds,
                color: glowColor,
                fade: widget.edgeFade,
                peakAlpha: layer.alpha,
              ),
          ),
        )..layout(maxWidth: widget.maxWidth),
    ];
    _revision += 1;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: _size,
      painter: _LuminescentTextPainter(
        glow: _glowPainters,
        fill: _fillPainter,
        revision: _revision,
      ),
    );
  }
}

/// Paints the pre-laid-out glow and fill [TextPainter]s.
class _LuminescentTextPainter extends CustomPainter {
  const _LuminescentTextPainter({
    required this.glow,
    required this.fill,
    required this.revision,
  });

  final List<TextPainter> glow;
  final TextPainter? fill;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    for (final painter in glow) {
      painter.paint(canvas, Offset.zero);
    }
    fill?.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(_LuminescentTextPainter oldDelegate) =>
      oldDelegate.revision != revision;
}

/// Audio intensity / spectrum source.
class AudioSpectrumService {
  /// Emits the current spectrum / level frames.
  Stream<List<double>> get frames => const Stream<List<double>>.empty();

  void dispose() {}
}

final audioSpectrumServiceProvider = Provider<AudioSpectrumService>((ref) {
  final service = AudioSpectrumService();
  ref.onDispose(service.dispose);
  return service;
});

/// Current audio spectrum (band magnitudes) exposed to the UI.
final audioSpectrumProvider = StreamProvider<List<double>>((ref) {
  return ref.watch(audioSpectrumServiceProvider).frames;
});

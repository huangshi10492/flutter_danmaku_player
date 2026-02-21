import 'dart:ui' as ui;

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// 章节显示条 - 在进度条上方显示章节分隔线和标题
class ChapterSegmentBar extends StatelessWidget {
  const ChapterSegmentBar({
    super.key,
    required this.chapters,
    required this.durationSeconds,
    this.height = 16,
  });
  final Map<int, String> chapters;
  final int durationSeconds;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _ChapterSegmentPainter(
        chapters: chapters,
        durationSeconds: durationSeconds,
      ),
    );
  }
}

class _ChapterSegmentPainter extends CustomPainter {
  _ChapterSegmentPainter({
    required this.chapters,
    required this.durationSeconds,
  }) : _sortedEntries = chapters.entries.toList()
         ..sort((a, b) => a.key.compareTo(b.key));

  final Map<int, String> chapters;
  final int durationSeconds;

  final List<MapEntry<int, String>> _sortedEntries;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint..color = Colors.grey.withValues(alpha: 0.3),
    );
    final dividerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.5);
    for (int i = 0; i < _sortedEntries.length; i++) {
      final entry = _sortedEntries[i];
      final startX = (entry.key / durationSeconds) * size.width;
      final endX = i + 1 < _sortedEntries.length
          ? (_sortedEntries[i + 1].key / durationSeconds) * size.width
          : size.width;
      if (entry.key > 0) {
        canvas.drawRect(
          Rect.fromLTRB(startX, 0, startX + 2, size.height),
          dividerPaint,
        );
      }
      final title = entry.value;
      if (title.isNotEmpty) {
        final titleStartX = startX + (entry.key > 0 ? 2 : 0);
        final titleWidth = endX - titleStartX;
        if (titleWidth > 0) {
          _drawChapterTitle(
            canvas,
            title,
            titleStartX,
            titleWidth,
            size.height,
          );
        }
      }
    }
  }

  void _drawChapterTitle(
    Canvas canvas,
    String title,
    double startX,
    double width,
    double height,
  ) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textDirection: TextDirection.ltr,
              strutStyle: ui.StrutStyle(leading: 0, height: 1, fontSize: 10),
            ),
          )
          ..pushStyle(
            ui.TextStyle(color: Colors.white, fontSize: 10, height: 1),
          )
          ..addText(title);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));

    final textWidth = paragraph.maxIntrinsicWidth;
    final textHeight = paragraph.height;

    if (textWidth > width) {
      final scale = width / textWidth;
      canvas
        ..save()
        ..translate(startX, (height - textHeight * scale) / 2)
        ..scale(scale);
      canvas.drawParagraph(paragraph, Offset.zero);
      paragraph.dispose();
      canvas.restore();
    } else {
      final offset = Offset(
        (width - textWidth) / 2 + startX,
        (height - textHeight) / 2,
      );
      canvas.drawParagraph(paragraph, offset);
      paragraph.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _ChapterSegmentPainter oldDelegate) {
    return durationSeconds != oldDelegate.durationSeconds ||
        chapters != oldDelegate.chapters;
  }
}

class DanmakuTrendChart extends StatelessWidget {
  const DanmakuTrendChart({
    super.key,
    required this.danmakuTrend,
    this.height = 16,
  });

  final List<double> danmakuTrend;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (danmakuTrend.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxY = danmakuTrend.reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            titlesData: const FlTitlesData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (danmakuTrend.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  danmakuTrend.length,
                  (index) => FlSpot(index.toDouble(), danmakuTrend[index]),
                ),
                isCurved: true,
                barWidth: 1,
                color: context.theme.colors.primary,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: context.theme.colors.primary.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoProgressBar extends StatefulWidget {
  const VideoProgressBar({
    super.key,
    required this.progress,
    required this.total,
    required this.buffered,
    required this.onSeek,
    this.danmakuTrend = const [],
    this.chapters = const {},
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final Duration progress;
  final Duration total;
  final Duration buffered;
  final ValueChanged<Duration> onSeek;
  final List<double> danmakuTrend;
  final Map<int, String> chapters;
  final ThumbDragStartCallback? onDragStart;
  final ThumbDragUpdateCallback? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  final chapterHeight = 16.0;
  final trendHeight = 16.0;
  final thumbRadius = 8.0;
  String? _cachedTotalTimeText;
  double? _cachedTimeLabelWidth;

  @override
  Widget build(BuildContext context) {
    final hasTrend = widget.danmakuTrend.isNotEmpty;
    final hasChapters =
        widget.chapters.isNotEmpty && widget.total.inSeconds > 0;
    final totalTimeText = Utils.formatDuration(widget.total);
    if (_cachedTotalTimeText != totalTimeText) {
      _cachedTotalTimeText = totalTimeText;
      _cachedTimeLabelWidth = _layoutTextWidth(totalTimeText);
    }
    final timeLabelWidth = _cachedTimeLabelWidth ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: timeLabelWidth + thumbRadius + 5,
            child: Text(
              Utils.formatDuration(widget.progress),
              style: context.theme.typography.sm,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 50,
            child: Stack(
              alignment: .bottomCenter,
              children: [
                if (hasChapters)
                  Positioned(
                    bottom: thumbRadius,
                    left: 0,
                    right: 0,
                    child: ChapterSegmentBar(
                      chapters: widget.chapters,
                      durationSeconds: widget.total.inSeconds,
                      height: chapterHeight,
                    ),
                  ),
                if (hasTrend)
                  Positioned(
                    bottom: hasChapters
                        ? chapterHeight + thumbRadius
                        : thumbRadius + 2,
                    left: 0,
                    right: 0,
                    child: DanmakuTrendChart(
                      danmakuTrend: widget.danmakuTrend,
                      height: trendHeight,
                    ),
                  ),
                RepaintBoundary(
                  child: ProgressBar(
                    progress: widget.progress,
                    total: widget.total,
                    buffered: widget.buffered,
                    onSeek: widget.onSeek,
                    thumbRadius: 8,
                    thumbGlowRadius: 18,
                    onDragStart: widget.onDragStart,
                    onDragUpdate: widget.onDragUpdate,
                    onDragEnd: widget.onDragEnd,
                    timeLabelLocation: .none,
                  ),
                ),
              ],
            ),
          ),
        ),
        RepaintBoundary(
          child: Container(
            margin: .only(left: thumbRadius + 5),
            width: timeLabelWidth,
            child: Text(
              Utils.formatDuration(widget.total),
              style: context.theme.typography.sm,
            ),
          ),
        ),
      ],
    );
  }

  double _layoutTextWidth(String text) {
    TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: context.theme.typography.sm),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
  }
}

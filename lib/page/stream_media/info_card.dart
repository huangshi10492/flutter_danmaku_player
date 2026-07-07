import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/widget/network_image.dart';
import 'package:fldanplay/widget/rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

class StreamMediaInfoCard extends StatelessWidget {
  final String title;
  final String mediaId;
  final String imageUrl;
  final Map<String, String>? headers;
  final bool isLoading;
  final bool showFavoriteAction;
  final bool isFavorite;
  final MediaDetail? mediaDetail;
  final VoidCallback? onToggleFavorite;

  const StreamMediaInfoCard({
    super.key,
    required this.title,
    required this.mediaId,
    required this.imageUrl,
    required this.headers,
    required this.isLoading,
    required this.showFavoriteAction,
    required this.isFavorite,
    required this.mediaDetail,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight, 16, 0),
          child: SizedBox(
            height: 250,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWideLayout = constraints.maxWidth > 550;
                return Column(
                  crossAxisAlignment: .start,
                  children: [
                    if (!isWideLayout) ...[
                      Text(
                        title,
                        style: context.theme.typography.body.xl.copyWith(
                          height: 1,
                        ),
                        maxLines: 2,
                        overflow: .ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Expanded(
                      child: Row(
                        crossAxisAlignment: .start,
                        children: [
                          AspectRatio(
                            aspectRatio: 0.7,
                            child: LayoutBuilder(
                              builder: (context, boxConstraints) => Hero(
                                transitionOnUserGestures: true,
                                tag: mediaId,
                                child: NetworkImageWidget(
                                  url: imageUrl,
                                  headers: headers,
                                  maxWidth: boxConstraints.maxWidth,
                                  maxHeight: boxConstraints.maxHeight,
                                  errorWidget: _buildEmptyPrefix(),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: .start,
                                children: [
                                  if (isWideLayout) ...[
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: .ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  _buildInfoBlocks(context),
                                  const Spacer(),
                                  _buildActionRow(context),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBlocks(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const ratingWidth = 100.0;
        const yearWidth = 70.0;
        const spacing = 32.0;
        final showYear = width >= ratingWidth + spacing + yearWidth;
        final showGenres =
            width >= ratingWidth + spacing + yearWidth + spacing + 80;
        return Skeletonizer(
          enabled: isLoading,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                SizedBox(
                  width: ratingWidth,
                  child: _buildRatingBlock(context, !showYear),
                ),
                if (showYear) ...[
                  const SizedBox(width: spacing),
                  SizedBox(width: yearWidth, child: _buildYearBlock(context)),
                ],
                if (showGenres &&
                    (mediaDetail?.genres.isNotEmpty ?? false)) ...[
                  const SizedBox(width: spacing),
                  Expanded(child: _buildGenresBlock(context)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  TextStyle _getValueTextStyle(BuildContext context, double fontSize) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: context.theme.colors.primary,
      );

  Widget _buildYearBlock(BuildContext context) {
    final yearText = mediaDetail?.productionYear?.toString() ?? '未知';
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        const Text('年份'),
        Text(
          yearText,
          style: _getValueTextStyle(context, 24).copyWith(height: 1.5),
          maxLines: 1,
          overflow: .ellipsis,
        ),
      ],
    );
  }

  Widget _buildRatingBlock(BuildContext context, bool showYearAbove) {
    final rating = mediaDetail?.rating ?? 0.0;
    final hasRating = mediaDetail != null && rating != 0;
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        if (showYearAbove) ...[
          _buildYearBlock(context),
          const SizedBox(height: 12),
        ],
        const Text('评分'),
        const SizedBox(height: 6),
        if (!hasRating)
          Text(
            '暂无评分',
            style: _getValueTextStyle(context, 20).copyWith(height: 1.2),
            maxLines: 1,
            overflow: .ellipsis,
          )
        else ...[
          RatingBar(rating: rating),
          Text(
            rating.toStringAsFixed(1),
            style: _getValueTextStyle(context, 22).copyWith(height: 1.4),
            maxLines: 1,
          ),
        ],
      ],
    );
  }

  Widget _buildGenresBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        const Text('分类'),
        const SizedBox(height: 6),
        Text(
          mediaDetail?.genres.join(' / ') ?? '',
          style: context.theme.typography.body.xs,
          overflow: .ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final moreButton = FButton.icon(
      variant: .ghost,
      size: .md,
      onPress: isLoading ? null : () => _showDetailsBottomSheet(context),
      child: const Icon(Icons.more_horiz),
    );
    if (!showFavoriteAction) return moreButton;
    return LayoutBuilder(
      builder: (context, constraints) {
        const buttonMaxWidth = 150.0;
        const moreButtonWidth = 48.0;
        const labelThreshold = 96.0;
        final availableWidth = constraints.maxWidth - moreButtonWidth - 4;
        final buttonWidth = availableWidth.clamp(0.0, buttonMaxWidth);
        final showLabel = buttonWidth >= labelThreshold;
        return Row(
          children: [
            if (buttonWidth > 0) ...[
              SizedBox(
                width: buttonWidth,
                child: FButton(
                  size: .sm,
                  onPress: isLoading ? null : onToggleFavorite,
                  child: Row(
                    mainAxisAlignment: .center,
                    children: [
                      Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                      ),
                      if (showLabel) ...[
                        const SizedBox(width: 8),
                        Text(isFavorite ? '已收藏' : '收藏'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            moreButton,
          ],
        );
      },
    );
  }

  Widget _buildEmptyPrefix() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: const Color.fromARGB(255, 25, 25, 25),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_outline, size: 50, color: Colors.grey),
      ),
    );
  }

  void _showDetailsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      context: context,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Container(
            decoration: BoxDecoration(
              color: context.theme.colors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: _buildDetail(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final rawOverview = mediaDetail?.overview;
    final overview = rawOverview == null
        ? '暂无简介'
        : rawOverview.replaceAll(RegExp(r'<br\s*/?>'), ' ').trim();
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text('简介', style: context.theme.typography.body.lg),
        Text(overview, style: context.theme.typography.body.md),
        const SizedBox(height: 16),
        Text('分类', style: context.theme.typography.body.lg),
        Text(
          mediaDetail?.genres.join(' / ') ?? '',
          style: context.theme.typography.body.md,
        ),
        const SizedBox(height: 16),
        Text('标签', style: context.theme.typography.body.lg),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              mediaDetail?.tags
                  .map((tag) => _buildTag(context, tag))
                  .toList() ??
              [],
        ),
        const SizedBox(height: 16),
        Text('外部链接', style: context.theme.typography.body.lg),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              mediaDetail?.externalUrls
                  .map(
                    (url) => FButton(
                      onPress: () => launchUrl(Uri.parse(url.url)),
                      variant: .outline,
                      mainAxisSize: .min,
                      child: Text(url.name),
                    ),
                  )
                  .toList() ??
              [],
        ),
      ],
    );
  }

  Widget _buildTag(BuildContext context, String tag) {
    return Padding(
      padding: const .all(2),
      child: FFocusedOutline(
        focused: true,
        style: .delta(color: context.theme.colors.mutedForeground),
        child: Padding(
          padding: const .symmetric(horizontal: 4, vertical: 2),
          child: Text(tag, style: context.theme.typography.body.sm),
        ),
      ),
    );
  }
}

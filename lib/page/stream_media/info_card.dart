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
  final MediaDetail? mediaDetail;

  const StreamMediaInfoCard({
    super.key,
    required this.title,
    required this.mediaId,
    required this.imageUrl,
    required this.headers,
    required this.isLoading,
    required this.mediaDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: SizedBox(
          height: 300,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isWideLayout = screenWidth > 650;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isWideLayout) ...[
                    Text(
                      title,
                      style: context.theme.typography.xl.copyWith(height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 0.7,
                          child: LayoutBuilder(
                            builder: (context, boxConstraints) {
                              final double maxWidth = boxConstraints.maxWidth;
                              final double maxHeight = boxConstraints.maxHeight;
                              return Hero(
                                transitionOnUserGestures: true,
                                tag: mediaId,
                                child: NetworkImageWidget(
                                  url: imageUrl,
                                  headers: headers,
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                  large: true,
                                  errorWidget: _buildEmtpyPrefix(),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: InkWell(
                              onTap: () => _showDetailsBottomSheet(context),
                              borderRadius: BorderRadius.circular(4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isWideLayout) ...[
                                    Text(
                                      title,
                                      style: context.theme.typography.xl2
                                          .copyWith(height: 1.4),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildInfoBlocks(context),
                                  const SizedBox(height: 8),
                                  if (mediaDetail?.overview != null)
                                    Flexible(child: _buildOverview(context)),
                                ],
                              ),
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
    );
  }

  Widget _buildInfoBlocks(BuildContext context) {
    final infoBlocks = [
      _buildYearBlock(context),
      _buildRatingBlock(context),
      if (mediaDetail?.genres.isNotEmpty == true) _buildGenresBlock(context),
    ];
    return Skeletonizer(
      enabled: isLoading,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(spacing: 16, runSpacing: 16, children: infoBlocks),
      ),
    );
  }

  Widget _buildYearBlock(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('年份:'),
          Text(
            (mediaDetail == null || mediaDetail!.productionYear == null)
                ? '未知'
                : mediaDetail!.productionYear.toString(),
            style: TextStyle(
              fontSize: 24,
              height: 1.5,
              fontWeight: FontWeight.bold,
              color: context.theme.colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBlock(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('评分:'),
          const SizedBox(height: 6),
          (mediaDetail == null || mediaDetail!.rating == 0)
              ? Text(
                  '暂无评分',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.bold,
                    color: context.theme.colors.primary,
                  ),
                )
              : RatingBar(rating: mediaDetail?.rating ?? 0.0),
          if (mediaDetail != null && mediaDetail!.rating != 0)
            Text(
              mediaDetail!.rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 22,
                height: 1.4,
                fontWeight: FontWeight.bold,
                color: context.theme.colors.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGenresBlock(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分类:'),
          const SizedBox(height: 6),
          Text(
            mediaDetail!.genres.join(' / '),
            style: const TextStyle(fontSize: 14, height: 1.25),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context) {
    final overview =
        mediaDetail?.overview?.replaceAll(RegExp(r'<br\s*/?>'), ' ').trim() ??
        '';
    final hasOverview = overview.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 100) {
          return const SizedBox();
        }
        return Skeletonizer(
          enabled: isLoading,
          child: Text(
            hasOverview ? overview : '暂无简介',
            style: context.theme.typography.base,
            overflow: TextOverflow.fade,
            softWrap: true,
          ),
        );
      },
    );
  }

  Widget _buildEmtpyPrefix() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: const Color.fromARGB(255, 25, 25, 25),
      ),
      child: const Center(
        child: Icon(Icons.folder_outlined, size: 50, color: Colors.grey),
      ),
    );
  }

  void _showDetailsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      context: context,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Container(
                decoration: BoxDecoration(
                  color: context.theme.colors.background,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildDetail(context),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('简介', style: context.theme.typography.xl),
        const SizedBox(height: 8),
        Text(
          mediaDetail?.overview == null
              ? '暂无简介'
              : (mediaDetail?.overview
                        ?.replaceAll(RegExp(r'<br\s*/?>'), ' ')
                        .trim()) ??
                    '',
          style: context.theme.typography.base,
        ),
        const SizedBox(height: 16),
        Text('标签', style: context.theme.typography.xl),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              mediaDetail?.tags.map((tag) {
                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: FFocusedOutline(
                    focused: true,
                    style: .delta(color: context.theme.colors.mutedForeground),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(tag, style: context.theme.typography.sm),
                    ),
                  ),
                );
              }).toList() ??
              [],
        ),
        const SizedBox(height: 16),
        Text('外部链接', style: context.theme.typography.xl),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              mediaDetail?.externalUrls.map((url) {
                return InkWell(
                  onTap: () => launchUrl(Uri.parse(url.url)),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: FFocusedOutline(
                      focused: true,
                      style: .delta(
                        color: context.theme.colors.mutedForeground,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          url.name,
                          style: context.theme.typography.base.copyWith(
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList() ??
              [],
        ),
      ],
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class NetworkImageWidget extends StatelessWidget {
  final String url;
  final Map<String, String>? headers;
  final double maxWidth;
  final double maxHeight;
  final Widget? errorWidget;
  final BoxFit fit;
  final Color? backgroundColor;
  final double radius;

  const NetworkImageWidget({
    super.key,
    required this.url,
    this.headers,
    required this.maxWidth,
    required this.maxHeight,
    this.errorWidget,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: .circular(radius),
      child: ColoredBox(
        color: backgroundColor ?? Colors.grey.shade800,
        child: CachedNetworkImage(
          imageUrl: url,
          httpHeaders: headers,
          width: maxWidth,
          height: maxHeight,
          memCacheWidth: maxWidth.cacheSize(context),
          errorWidget: (context, url, error) {
            if (errorWidget != null) {
              return errorWidget!;
            }
            return const SizedBox.shrink();
          },
          placeholder: (context, url) {
            if (errorWidget != null) {
              return errorWidget!;
            }
            return const SizedBox.shrink();
          },
          filterQuality: FilterQuality.high,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 0),
          fadeOutDuration: const Duration(milliseconds: 0),
        ),
      ),
    );
  }
}

extension ImageExtension on num {
  int cacheSize(BuildContext context) {
    return (this * MediaQuery.of(context).devicePixelRatio).round();
  }
}

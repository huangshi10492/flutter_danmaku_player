import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

class NetworkImageWidget extends StatelessWidget {
  final String url;
  final Map<String, String>? headers;
  final double width;
  final double height;
  final Widget? errorWidget;
  final BoxFit fit;
  final double radius;

  const NetworkImageWidget({
    super.key,
    required this.url,
    this.headers,
    required this.width,
    required this.height,
    this.errorWidget,
    this.fit = BoxFit.cover,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    int? memCacheWidth, memCacheHeight;
    if (width <= height) {
      memCacheWidth = width.cacheSize(context);
    } else {
      memCacheHeight = height.cacheSize(context);
    }
    return ClipRRect(
      borderRadius: .circular(radius),
      child: ColoredBox(
        color: Colors.grey.shade800,
        child: CachedNetworkImage(
          cacheManager: DefaultCacheManager.instance,
          imageUrl: url,
          httpHeaders: headers,
          width: width,
          height: height,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          errorBuilder: (context, url, error) {
            if (errorWidget != null) return errorWidget!;
            return const SizedBox.shrink();
          },
          placeholder: (_, _) => Container(
            color: const Color.fromARGB(255, 25, 25, 25),
            child: Center(child: const FCircularProgress(size: .lg)),
          ),
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 100),
          fadeOutDuration: const Duration(milliseconds: 100),
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

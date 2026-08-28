import 'package:material_ui/material_ui.dart';

class RatingBar extends StatelessWidget {
  // 0-10
  const RatingBar({this.rating = 0.0, super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    Widget item({required bool filled}) {
      return Icon(
        Icons.star,
        color: filled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).disabledColor,
        size: 20,
      );
    }

    final starRating = rating / 2.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final fillRatio = (starRating - index).clamp(0.0, 1.0);
        return SizedBox(
          width: 20,
          height: 20,
          child: Stack(
            children: [
              item(filled: false),
              ClipRect(
                clipper: _StarClipper(fillRatio),
                child: item(filled: true),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// 自定义裁剪器，用于显示部分星星
class _StarClipper extends CustomClipper<Rect> {
  final double ratio;

  const _StarClipper(this.ratio);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0.0, 0.0, size.width * ratio, size.height);
  }

  @override
  bool shouldReclip(_StarClipper oldClipper) {
    return oldClipper.ratio != ratio;
  }
}

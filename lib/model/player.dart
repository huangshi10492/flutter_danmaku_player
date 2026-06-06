class SubtitleStyle {
  int fontSize;
  int marginY;

  SubtitleStyle({this.fontSize = 50, this.marginY = 34});

  Map<String, dynamic> toJson() => {'font_size': fontSize, 'margin_y': marginY};

  factory SubtitleStyle.fromJson(Map<String, dynamic> json) => SubtitleStyle(
    fontSize: json['font_size'] ?? 40,
    marginY: json['margin_y'] ?? 30,
  );

  SubtitleStyle copyWith({int? fontSize, int? marginY}) => SubtitleStyle(
    fontSize: fontSize ?? this.fontSize,
    marginY: marginY ?? this.marginY,
  );
}

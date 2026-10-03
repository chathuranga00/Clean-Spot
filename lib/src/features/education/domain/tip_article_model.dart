class TipArticleModel {
  final String id;
  final String title;
  final String content;
  final String category; // 'prevention' | 'symptoms' | 'treatment'

  const TipArticleModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
  });
}

import 'package:app/gen/assets.gen.dart';

enum RankGemStyle {
  pearl,
  moonstone,
  jade,
  lapisLazuli,
  ammolite,
  onyx,
  supernova,
}

class RankCardItem {
  const RankCardItem({
    required this.name,
    required this.tier,
    required this.headline,
    required this.description,
    required this.requiredHonorLabel,
    required this.image,
    required this.gemStyle,
    required this.filledTierCount,
    this.thresholdLabelAbove,
  });

  final String name;
  final String tier;
  final String headline;
  final String description;
  final String requiredHonorLabel;
  final AssetGenImage image;
  final RankGemStyle gemStyle;
  final int filledTierCount;
  final String? thresholdLabelAbove;
}

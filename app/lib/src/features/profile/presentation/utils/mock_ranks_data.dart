import 'package:app/gen/assets.gen.dart';
import 'package:app/src/features/profile/presentation/models/rank_card_item.dart';

List<RankCardItem> mockRanks = [
  RankCardItem(
    name: 'Pearl',
    tier: 'Awareness',
    headline: 'Beginning of the path.',
    description:
        'The member shows conscious participation and earns recognition for consistent, real actions.',
    requiredHonorLabel: '0',
    image: Assets.images.pearl,
    gemStyle: RankGemStyle.pearl,
    filledTierCount: 4,
  ),
  RankCardItem(
    name: 'Moonstone',
    tier: 'Intention',
    headline: 'Actions become deliberate.',
    description:
        'The member acts with purpose and supports others in a meaningful way.',
    requiredHonorLabel: '10-29',
    image: Assets.images.moonstone,
    gemStyle: RankGemStyle.moonstone,
    filledTierCount: 3,
    thresholdLabelAbove: '10',
  ),
  RankCardItem(
    name: 'Jade',
    tier: 'Discipline',
    headline: 'Consistency under control.',
    description:
        'Recognition reflects reliability, self-control, and repeated contribution over time.',
    requiredHonorLabel: '30-69',
    image: Assets.images.jade,
    gemStyle: RankGemStyle.jade,
    filledTierCount: 0,
    thresholdLabelAbove: '30',
  ),
  RankCardItem(
    name: 'Lapis Lazuli',
    tier: 'Influence',
    headline: 'Impact extends beyond self.',
    description:
        'The member\'s actions begin shaping the behavior and standards of others.',
    requiredHonorLabel: '70+',
    image: Assets.images.lapislazuli,
    gemStyle: RankGemStyle.lapisLazuli,
    filledTierCount: 0,
    thresholdLabelAbove: '70',
  ),
  RankCardItem(
    name: 'Ammolite',
    tier: 'Fortitude',
    headline: 'Strength through pressure.',
    description:
        'Recognition reflects resilience, long-term commitment, and stability in difficult moments.',
    requiredHonorLabel: '170+',
    image: Assets.images.ammolite,
    gemStyle: RankGemStyle.ammolite,
    filledTierCount: 0,
    thresholdLabelAbove: '170',
  ),
  RankCardItem(
    name: 'Onyx',
    tier: 'Transcendence',
    headline: 'Above ego and noise.',
    description:
        'The member is respected for composure, principles, and clean conduct even when unseen.',
    requiredHonorLabel: '300+',
    image: Assets.images.onyx,
    gemStyle: RankGemStyle.onyx,
    filledTierCount: 0,
    thresholdLabelAbove: '300',
  ),
  RankCardItem(
    name: 'Supernova',
    tier: 'Sovereign',
    headline: 'System-level recognition.',
    description:
        'Top-tier rank awarded for sustained impact, influence, and community-wide respect.',
    requiredHonorLabel: '1000+',
    image: Assets.images.supernova,
    gemStyle: RankGemStyle.supernova,
    filledTierCount: 0,
    thresholdLabelAbove: '1000',
  ),
];

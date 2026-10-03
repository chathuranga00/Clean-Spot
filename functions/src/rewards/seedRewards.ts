import * as admin from 'firebase-admin';

export interface SeedRewardDef {
  rewardId: string;
  title: string;
  description: string;
  costPoints: number;
  category: 'repellent' | 'larvicide' | 'certificate' | 'equipment';
  stockCount: number;
  isActive: boolean;
  expiresInDays?: number; // negative for expired demo
  imageUrl?: string;
  coupons: string[];
}

export const DEMO_REWARDS_CATALOG: SeedRewardDef[] = [
  {
    rewardId: 'reward_coils_10pk',
    title: 'Mosquito Repellent Coils (10-pack)',
    description: 'Organic citronella and neem active mosquito coils for continuous smoke-screen barrier defense.',
    costPoints: 100,
    category: 'repellent',
    stockCount: 5,
    isActive: true,
    expiresInDays: 90,
    imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=400',
    coupons: [
      'DEMO-COIL-101',
      'DEMO-COIL-102',
      'DEMO-COIL-103',
      'DEMO-COIL-104',
      'DEMO-COIL-105',
    ],
  },
  {
    rewardId: 'reward_abate_larvicide',
    title: 'Abate 1SG Larvicide Kit',
    description: 'Granular temephos 1% vector control treatment safe for potable and non-potable storage containers.',
    costPoints: 150,
    category: 'larvicide',
    stockCount: 3,
    isActive: true,
    expiresInDays: 60,
    imageUrl: 'https://images.unsplash.com/photo-1544816155-12df9643f363?w=400',
    coupons: [
      'DEMO-ABATE-201',
      'DEMO-ABATE-202',
      'DEMO-ABATE-203',
    ],
  },
  {
    rewardId: 'reward_phi_certificate',
    title: 'National Dengue Center Certificate',
    description: 'Official framed civic defense commendation signed by National Dengue Control Unit officers.',
    costPoints: 250,
    category: 'certificate',
    stockCount: 10,
    isActive: true,
    expiresInDays: 365,
    imageUrl: 'https://images.unsplash.com/photo-1530587191325-3db32d826c18?w=400',
    coupons: [
      'DEMO-CERT-301',
      'DEMO-CERT-302',
      'DEMO-CERT-303',
      'DEMO-CERT-304',
    ],
  },
  {
    rewardId: 'reward_expired_demo',
    title: 'Monsoon Flash Kit (Expired Demo)',
    description: 'Promotional seasonal campaign kit included for expired offer rejection testing.',
    costPoints: 75,
    category: 'equipment',
    stockCount: 2,
    isActive: true,
    expiresInDays: -5, // Expired 5 days ago
    imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=400',
    coupons: [
      'DEMO-EXP-401',
      'DEMO-EXP-402',
    ],
  },
];

/**
 * Seeds DEMO rewards and their associated coupons into Firestore.
 */
export async function seedDemoRewardsAndCoupons(
  db: admin.firestore.Firestore,
  nowDate: Date = new Date()
): Promise<void> {
  for (const reward of DEMO_REWARDS_CATALOG) {
    const rewardRef = db.collection('rewards').doc(reward.rewardId);

    const expiry = reward.expiresInDays !== undefined
      ? new Date(nowDate.getTime() + reward.expiresInDays * 24 * 60 * 60 * 1000)
      : null;

    await rewardRef.set({
      rewardId: reward.rewardId,
      title: reward.title,
      description: reward.description,
      costPoints: reward.costPoints,
      category: reward.category,
      stockCount: reward.stockCount,
      isActive: reward.isActive,
      expiresAt: expiry ? admin.firestore.Timestamp.fromDate(expiry) : null,
      imageUrl: reward.imageUrl,
      createdAt: admin.firestore.Timestamp.fromDate(nowDate),
      updatedAt: admin.firestore.Timestamp.fromDate(nowDate),
    });

    // Seed coupons subcollection
    for (let i = 0; i < reward.coupons.length; i++) {
      const code = reward.coupons[i];
      const couponId = `coupon_${reward.rewardId}_${i + 1}`;
      const couponRef = rewardRef.collection('coupons').doc(couponId);

      await couponRef.set({
        couponId,
        rewardId: reward.rewardId,
        code,
        isRedeemed: false,
        redeemedBy: null,
        redeemedAt: null,
        redemptionId: null,
        createdAt: admin.firestore.Timestamp.fromDate(nowDate),
      });
    }
  }
}

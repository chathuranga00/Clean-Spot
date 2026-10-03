import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cleanspot/src/features/auth/data/auth_repository.dart';
import 'package:cleanspot/src/features/rewards/domain/redemption_model.dart';
import 'package:cleanspot/src/features/rewards/domain/reward_model.dart';

abstract class RewardRepository {
  Stream<List<RewardModel>> watchRewards();
  Stream<List<RedemptionModel>> watchUserRedemptions(String userId);
  Future<RedemptionModel> redeemReward({
    required String rewardId,
    required String idempotencyKey,
  });
}

class FirestoreRewardRepository implements RewardRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirestoreRewardRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  @override
  Stream<List<RewardModel>> watchRewards() {
    return _firestore
        .collection('rewards')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RewardModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Stream<List<RedemptionModel>> watchUserRedemptions(String userId) {
    return _firestore
        .collection('redemptions')
        .where('userId', isEqualTo: userId)
        .orderBy('redeemedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RedemptionModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<RedemptionModel> redeemReward({
    required String rewardId,
    required String idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('redeemReward');
    final response = await callable.call<Map<String, dynamic>>({
      'rewardId': rewardId,
      'idempotencyKey': idempotencyKey,
    });

    final data = Map<String, dynamic>.from(response.data);
    return RedemptionModel.fromMap(
      data['redemptionId'] as String? ?? idempotencyKey,
      data,
    );
  }
}

final rewardRepositoryProvider = Provider<RewardRepository>((ref) {
  return FirestoreRewardRepository();
});

final rewardsStreamProvider = StreamProvider<List<RewardModel>>((ref) {
  final repository = ref.watch(rewardRepositoryProvider);
  return repository.watchRewards();
});

final userRedemptionsStreamProvider =
    StreamProvider<List<RedemptionModel>>((ref) {
  final user = ref.watch(authStateChangesProvider).value ??
      ref.watch(authRepositoryProvider).currentUser;
  if (user == null) {
    return Stream.value(const []);
  }
  final repository = ref.watch(rewardRepositoryProvider);
  return repository.watchUserRedemptions(user.uid);
});

class RedeemRewardState {
  final bool isLoading;
  final String? error;
  final RedemptionModel? lastRedemption;

  const RedeemRewardState({
    this.isLoading = false,
    this.error,
    this.lastRedemption,
  });

  RedeemRewardState copyWith({
    bool? isLoading,
    String? error,
    RedemptionModel? lastRedemption,
  }) {
    return RedeemRewardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRedemption: lastRedemption ?? this.lastRedemption,
    );
  }
}

class RedeemRewardNotifier extends Notifier<RedeemRewardState> {
  @override
  RedeemRewardState build() => const RedeemRewardState();

  Future<RedemptionModel?> redeem({
    required String rewardId,
    required String idempotencyKey,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repository = ref.read(rewardRepositoryProvider);
      final redemption = await repository.redeemReward(
        rewardId: rewardId,
        idempotencyKey: idempotencyKey,
      );
      state = state.copyWith(
        isLoading: false,
        lastRedemption: redemption,
      );
      return redemption;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('FirebaseFunctionsException: ', ''),
      );
      return null;
    }
  }
}

final redeemRewardControllerProvider =
    NotifierProvider<RedeemRewardNotifier, RedeemRewardState>(
  RedeemRewardNotifier.new,
);

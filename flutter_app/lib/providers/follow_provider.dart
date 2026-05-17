import 'package:flutter_riverpod/flutter_riverpod.dart';

class FollowNotifier extends StateNotifier<Set<int>> {
  FollowNotifier() : super({});

  void toggle(int id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  bool isFollowing(int id) => state.contains(id);
}

final followedCampaignsProvider =
    StateNotifierProvider<FollowNotifier, Set<int>>(
  (_) => FollowNotifier(),
);

final followedNgosProvider =
    StateNotifierProvider<FollowNotifier, Set<int>>(
  (_) => FollowNotifier(),
);

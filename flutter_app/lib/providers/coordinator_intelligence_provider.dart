import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';

class OperationalIntelligence {
  final List<dynamic> stuckTasks;
  final Map<String, int> verificationStats;
  final List<dynamic> topVolunteers;
  final List<dynamic> ngoPerformance;

  OperationalIntelligence({
    required this.stuckTasks,
    required this.verificationStats,
    required this.topVolunteers,
    required this.ngoPerformance,
  });

  factory OperationalIntelligence.fromJson(Map<String, dynamic> json) {
    return OperationalIntelligence(
      stuckTasks: json['stuck_tasks'] ?? [],
      verificationStats: Map<String, int>.from(json['verification_stats'] ?? {}),
      topVolunteers: json['top_volunteers'] ?? [],
      ngoPerformance: json['ngo_performance'] ?? [],
    );
  }
}

class FraudSignals {
  final List<dynamic> gpsMismatches;
  final List<dynamic> highRiskVolunteers;

  FraudSignals({
    required this.gpsMismatches,
    required this.highRiskVolunteers,
  });

  factory FraudSignals.fromJson(Map<String, dynamic> json) {
    return FraudSignals(
      gpsMismatches: json['gps_mismatches'] ?? [],
      highRiskVolunteers: json['high_risk_volunteers'] ?? [],
    );
  }
}

final coordinatorIntelligenceProvider = FutureProvider<OperationalIntelligence>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/coordinator/intelligence');
  return OperationalIntelligence.fromJson(response.data['data']);
});

final fraudSignalsProvider = FutureProvider<FraudSignals>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/coordinator/signals');
  return FraudSignals.fromJson(response.data['data']);
});

final escalationHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/coordinator/escalations');
  return response.data['data'] ?? [];
});

class IntelligenceActionNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _client;
  final Ref _ref;

  IntelligenceActionNotifier(this._client, this._ref) : super(const AsyncValue.data(null));

  Future<void> escalate({
    required String entity,
    required int id,
    required String reason,
    required String severity,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.post('/coordinator/escalate', data: {
        'entity': entity,
        'id': id,
        'payload': {
          'reason': reason,
          'severity': severity,
          'timestamp': DateTime.now().toIso8601String(),
        }
      });
      // Invalidate to refresh views
      _ref.invalidate(fraudSignalsProvider);
    });
  }

  Future<void> flag({
    required String entity,
    required int id,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.post('/coordinator/flag', data: {
        'entity': entity,
        'id': id,
        'payload': {
          'reason': reason,
          'severity': 'MEDIUM',
        }
      });
      _ref.invalidate(fraudSignalsProvider);
    });
  }

  Future<void> broadcast({
    required String scope,
    required String targetId,
    required String message,
    required String urgency,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.post('/coordinator/broadcast', data: {
        'scope': scope,
        'targetId': targetId,
        'message': message,
        'urgency': urgency,
      });
    });
  }

  Future<void> emergencyEscalate({
    required String targetEntity,
    required int targetId,
    required String reason,
    required String severity,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.post('/coordinator/emergency-escalate', data: {
        'target_entity': targetEntity,
        'target_id': targetId,
        'reason': reason,
        'severity': severity,
      });
    });
  }
}

final intelligenceActionProvider = StateNotifierProvider<IntelligenceActionNotifier, AsyncValue<void>>((ref) {
  final client = ref.read(apiClientProvider);
  return IntelligenceActionNotifier(client, ref);
});

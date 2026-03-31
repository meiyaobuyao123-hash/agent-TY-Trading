import 'package:flutter_test/flutter_test.dart';
import 'package:ty_trading/shared/models/judgment.dart';

void main() {
  group('Judgment', () {
    final json = {
      'id': 'abc-123',
      'market_id': 'mkt-456',
      'symbol': 'BTC-USD',
      'direction': 'up',
      'confidence': 'high',
      'confidence_score': 0.85,
      'rational_price': 65000.0,
      'deviation_pct': 2.5,
      'reasoning': 'Strong bullish momentum',
      'model_votes': [
        {
          'model_name': 'claude',
          'direction': 'up',
          'confidence': 0.9,
          'rational_price': 66000.0,
          'reasoning': 'Bullish pattern',
        },
      ],
      'horizon_hours': 4,
      'expires_at': '2026-03-31T12:00:00',
      'created_at': '2026-03-31T08:00:00',
      'is_settled': false,
      'is_correct': null,
    };

    test('fromJson parses all fields correctly', () {
      final judgment = Judgment.fromJson(json);

      expect(judgment.id, 'abc-123');
      expect(judgment.marketId, 'mkt-456');
      expect(judgment.symbol, 'BTC-USD');
      expect(judgment.direction, 'up');
      expect(judgment.confidence, 'high');
      expect(judgment.confidenceScore, 0.85);
      expect(judgment.rationalPrice, 65000.0);
      expect(judgment.deviationPct, 2.5);
      expect(judgment.reasoning, 'Strong bullish momentum');
      expect(judgment.modelVotes, isNotNull);
      expect(judgment.modelVotes!.length, 1);
      expect(judgment.modelVotes!.first.modelName, 'claude');
      expect(judgment.horizonHours, 4);
      expect(judgment.isSettled, false);
      expect(judgment.isCorrect, isNull);
    });

    test('fromJson handles null optional fields', () {
      final minimal = {
        'id': 'abc-123',
        'market_id': 'mkt-456',
        'direction': 'down',
        'confidence': 'low',
        'confidence_score': 0.3,
        'created_at': '2026-03-31T08:00:00',
      };

      final judgment = Judgment.fromJson(minimal);
      expect(judgment.symbol, isNull);
      expect(judgment.rationalPrice, isNull);
      expect(judgment.reasoning, isNull);
      expect(judgment.modelVotes, isNull);
      expect(judgment.isCorrect, isNull);
    });

    test('equality by id', () {
      final j1 = Judgment.fromJson(json);
      final j2 = Judgment.fromJson(json);
      expect(j1, equals(j2));
      expect(j1.hashCode, equals(j2.hashCode));
    });

    test('inequality for different ids', () {
      final json2 = Map<String, dynamic>.from(json);
      json2['id'] = 'different-id';
      final j1 = Judgment.fromJson(json);
      final j2 = Judgment.fromJson(json2);
      expect(j1, isNot(equals(j2)));
    });
  });

  group('ModelVote', () {
    test('fromJson parses correctly', () {
      final json = {
        'model_name': 'gpt-4o',
        'direction': 'down',
        'confidence': 0.7,
        'rational_price': 62000.0,
        'reasoning': 'Bearish divergence',
      };

      final vote = ModelVote.fromJson(json);
      expect(vote.modelName, 'gpt-4o');
      expect(vote.direction, 'down');
      expect(vote.confidence, 0.7);
      expect(vote.rationalPrice, 62000.0);
      expect(vote.reasoning, 'Bearish divergence');
    });
  });
}

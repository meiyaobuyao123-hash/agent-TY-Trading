import 'package:flutter_test/flutter_test.dart';
import 'package:ty_trading/shared/models/market.dart';
import 'package:ty_trading/shared/models/market_snapshot.dart';

void main() {
  group('Market', () {
    final json = {
      'id': 'mkt-123',
      'symbol': 'BTC-USD',
      'name': 'Bitcoin',
      'market_type': 'crypto',
      'source': 'binance',
      'is_active': true,
      'created_at': '2026-03-31T00:00:00',
      'latest_snapshot': {
        'id': 'snap-1',
        'price': 64500.0,
        'volume': 12345.0,
        'change_pct': 2.5,
        'captured_at': '2026-03-31T08:00:00',
      },
    };

    test('fromJson parses all fields', () {
      final market = Market.fromJson(json);

      expect(market.id, 'mkt-123');
      expect(market.symbol, 'BTC-USD');
      expect(market.name, 'Bitcoin');
      expect(market.marketType, 'crypto');
      expect(market.source, 'binance');
      expect(market.isActive, true);
      expect(market.latestSnapshot, isNotNull);
      expect(market.latestSnapshot!.price, 64500.0);
    });

    test('fromJson handles null snapshot', () {
      final noSnap = Map<String, dynamic>.from(json);
      noSnap['latest_snapshot'] = null;
      final market = Market.fromJson(noSnap);
      expect(market.latestSnapshot, isNull);
    });

    test('equality by id', () {
      final m1 = Market.fromJson(json);
      final m2 = Market.fromJson(json);
      expect(m1, equals(m2));
      expect(m1.hashCode, equals(m2.hashCode));
    });

    test('inequality for different ids', () {
      final json2 = Map<String, dynamic>.from(json);
      json2['id'] = 'different-id';
      final m1 = Market.fromJson(json);
      final m2 = Market.fromJson(json2);
      expect(m1, isNot(equals(m2)));
    });
  });

  group('MarketSnapshot', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'snap-1',
        'price': 64500.0,
        'volume': 12345.0,
        'change_pct': -1.2,
        'captured_at': '2026-03-31T08:00:00',
      };

      final snap = MarketSnapshot.fromJson(json);
      expect(snap.id, 'snap-1');
      expect(snap.price, 64500.0);
      expect(snap.volume, 12345.0);
      expect(snap.changePct, -1.2);
    });

    test('fromJson handles null price/volume', () {
      final json = {
        'id': 'snap-2',
        'price': null,
        'volume': null,
        'change_pct': null,
        'captured_at': '2026-03-31T08:00:00',
      };

      final snap = MarketSnapshot.fromJson(json);
      expect(snap.price, isNull);
      expect(snap.volume, isNull);
      expect(snap.changePct, isNull);
    });
  });
}

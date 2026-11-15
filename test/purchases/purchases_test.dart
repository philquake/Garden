import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/purchases/purchases.dart';
import 'package:garden/state/garden_controller.dart';

import '../support.dart';

ProviderContainer containerWith(Purchases p) {
  final c = ProviderContainer(
    overrides: [purchasesProvider.overrideWithValue(p)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> pumpMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  group('unlock state', () {
    test('starts locked, then follows what the store says is owned', () async {
      final c = containerWith(FakePurchases(owned: true));
      expect(c.read(unlockedProvider), isFalse);
      await pumpMicrotasks();
      expect(c.read(unlockedProvider), isTrue);
    });

    test(
      'with no store connected, nothing can be bought or restored',
      () async {
        final c = containerWith(const NoStorePurchases());
        await pumpMicrotasks();
        expect(c.read(unlockedProvider), isFalse);
        expect(
          await c.read(unlockedProvider.notifier).buy(),
          PurchaseResult.unavailable,
        );
        expect(await c.read(unlockedProvider.notifier).restore(), isFalse);
        expect(c.read(unlockedProvider), isFalse);
      },
    );

    test('buying unlocks; cancelling or failing does not', () async {
      for (final r in [PurchaseResult.cancelled, PurchaseResult.failed]) {
        final c = containerWith(FakePurchases(buyResult: r));
        expect(await c.read(unlockedProvider.notifier).buy(), r);
        expect(c.read(unlockedProvider), isFalse);
      }
      final c = containerWith(FakePurchases());
      expect(
        await c.read(unlockedProvider.notifier).buy(),
        PurchaseResult.unlocked,
      );
      expect(c.read(unlockedProvider), isTrue);
    });

    test('restore unlocks only when a purchase was found', () async {
      final none = containerWith(FakePurchases());
      expect(await none.read(unlockedProvider.notifier).restore(), isFalse);
      expect(none.read(unlockedProvider), isFalse);
      final some = containerWith(FakePurchases(restorable: true));
      expect(await some.read(unlockedProvider.notifier).restore(), isTrue);
      expect(some.read(unlockedProvider), isTrue);
    });

    test('a store that throws leaves the garden locked, not broken', () async {
      final c = containerWith(_Throwing());
      await pumpMicrotasks();
      expect(c.read(unlockedProvider), isFalse);
    });
  });

  group('free tier', () {
    test('a free garden holds three habits and refuses a fourth', () async {
      final c = makeContainer(
        unlocked: false,
        habits: [
          for (final id in ['a', 'b', 'c']) tracked(habit(id)),
        ],
      );
      expect(
        () => c.read(gardenProvider.notifier).add(habit('d')),
        throwsA(isA<FreeLimitReached>()),
      );
      expect(c.read(gardenProvider).length, 3);
    });

    test(
      'the limit is on adding: existing habits and edits are untouched',
      () async {
        final c = makeContainer(
          unlocked: false,
          habits: [
            for (final id in ['a', 'b', 'c', 'd']) tracked(habit(id)),
          ],
        );
        await c
            .read(gardenProvider.notifier)
            .update(habit('d', name: 'Renamed'));
        await c.read(gardenProvider.notifier).setValue('d', testToday, 1);
        expect(c.read(gardenProvider).length, 4);
      },
    );

    test('an unlocked garden has no limit', () async {
      final c = makeContainer(
        habits: [
          for (final id in ['a', 'b', 'c']) tracked(habit(id)),
        ],
      );
      await c.read(gardenProvider.notifier).add(habit('d'));
      await c.read(gardenProvider.notifier).add(habit('e'));
      expect(c.read(gardenProvider).length, 5);
    });
  });
}

class _Throwing implements Purchases {
  @override
  Future<bool> isUnlocked() => throw StateError('offline');

  @override
  String get priceLabel => fallbackPrice;

  @override
  Future<PurchaseResult> buy() => throw StateError('offline');

  @override
  Future<bool> restore() => throw StateError('offline');
}

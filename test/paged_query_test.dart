import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/services/paged_query.dart';

void main() {
  group('fetchAllPages', () {
    test('reads every page when the result exceeds one request', () async {
      final ranges = <List<int>>[];
      final values = List<int>.generate(8, (index) => index);

      final result = await fetchAllPages<int>(
        pageSize: 3,
        fetchPage: (from, to) async {
          ranges.add([from, to]);
          return values.skip(from).take(to - from + 1).toList();
        },
      );

      expect(result, values);
      expect(ranges, [
        [0, 2],
        [3, 5],
        [6, 8],
      ]);
    });

    test('honors a small limit for lightweight home rails', () async {
      final ranges = <List<int>>[];
      final values = List<int>.generate(20, (index) => index);

      final result = await fetchAllPages<int>(
        pageSize: 3,
        limit: 4,
        fetchPage: (from, to) async {
          ranges.add([from, to]);
          return values.skip(from).take(to - from + 1).toList();
        },
      );

      expect(result, [0, 1, 2, 3]);
      expect(ranges, [
        [0, 2],
        [3, 3],
      ]);
    });

    test('returns empty for a zero limit without querying', () async {
      var called = false;
      final result = await fetchAllPages<int>(
        limit: 0,
        fetchPage: (from, to) async {
          called = true;
          return [1];
        },
      );
      expect(result, isEmpty);
      expect(called, isFalse);
    });
  });
}

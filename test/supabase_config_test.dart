import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/core/supabase_config.dart';

void main() {
  group('Supabase URL validation', () {
    test('accepts canonical project URLs with 19–20 character refs and optional trailing slash', () {
      expect(isValidSupabaseUrl('https://abcdefghijklmnopqrst.supabase.co'), isTrue);
      expect(isValidSupabaseUrl('https://abcdefghijklmnopqrs.supabase.co'), isTrue);
      expect(isValidSupabaseUrl(' https://abcdefghijklmnopqrst.supabase.co/// '), isTrue);
      expect(normalizeSupabaseUrl(' https://abcdefghijklmnopqrst.supabase.co/// '),
          'https://abcdefghijklmnopqrst.supabase.co');
    });

    test('rejects dashboard URLs, REST paths, query strings, and HTTP', () {
      expect(isValidSupabaseUrl('https://supabase.com/dashboard/project/abcdefghijklmnopqrst'), isFalse);
      expect(isValidSupabaseUrl('https://abcdefghijklmnopqrst.supabase.co/rest/v1'), isFalse);
      expect(isValidSupabaseUrl('https://abcdefghijklmnopqrst.supabase.co?x=1'), isFalse);
      expect(isValidSupabaseUrl('http://abcdefghijklmnopqrst.supabase.co'), isFalse);
    });

    test('rejects credentials, ports, and malformed project references', () {
      expect(isValidSupabaseUrl('https://user:pass@abcdefghijklmnopqrst.supabase.co'), isFalse);
      expect(isValidSupabaseUrl('https://abcdefghijklmnopqrst.supabase.co:8443'), isFalse);
      expect(isValidSupabaseUrl('https://project_ref.supabase.co'), isFalse);
      expect(isValidSupabaseUrl('https://abcdefghijklmnopqr.supabase.co'), isFalse);
      expect(isValidSupabaseUrl('https://abcdefghijklmnopqrstu.supabase.co'), isFalse);
      expect(isValidSupabaseUrl('https://abcdefghijklmnopqrs.foo.supabase.co'), isFalse);
    });
  });
}

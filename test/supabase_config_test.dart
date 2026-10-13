import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/core/supabase_config.dart';

void main() {
  group('Supabase URL validation', () {
    test('accepts a canonical project URL with optional trailing slash', () {
      expect(isValidSupabaseUrl('https://project-ref.supabase.co'), isTrue);
      expect(isValidSupabaseUrl(' https://project-ref.supabase.co/// '), isTrue);
      expect(normalizeSupabaseUrl(' https://project-ref.supabase.co/// '),
          'https://project-ref.supabase.co');
    });

    test('rejects dashboard URLs, REST paths, query strings, and HTTP', () {
      expect(isValidSupabaseUrl('https://supabase.com/dashboard/project/project-ref'), isFalse);
      expect(isValidSupabaseUrl('https://project-ref.supabase.co/rest/v1'), isFalse);
      expect(isValidSupabaseUrl('https://project-ref.supabase.co?x=1'), isFalse);
      expect(isValidSupabaseUrl('http://project-ref.supabase.co'), isFalse);
    });

    test('rejects credentials, ports, and malformed project references', () {
      expect(isValidSupabaseUrl('https://user:pass@project-ref.supabase.co'), isFalse);
      expect(isValidSupabaseUrl('https://project-ref.supabase.co:8443'), isFalse);
      expect(isValidSupabaseUrl('https://project_ref.supabase.co'), isFalse);
    });
  });
}

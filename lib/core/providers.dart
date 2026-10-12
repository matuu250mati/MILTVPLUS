import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_pin_service.dart';

final securePinServiceProvider = Provider<SecurePinService>(
  (ref) => SecurePinService(),
);

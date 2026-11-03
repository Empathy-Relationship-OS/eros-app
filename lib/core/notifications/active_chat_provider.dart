import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Date id (as a String, like every other date route) of the chat screen on screen, or null.
final activeChatDateIdProvider = StateProvider<String?>((ref) => null);

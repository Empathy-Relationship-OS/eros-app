import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The date id of the chat screen on screen, or null when none is.
///
/// The chat screen sets it while it's open (CH-F2). The foreground push handler reads it to
/// skip the banner for the chat the user is already looking at (CH-F1). Date ids are
/// Strings here, as in every date route.
final activeChatDateIdProvider = StateProvider<String?>((ref) => null);

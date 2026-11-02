import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/features/chat/data/repositories/chat_repository.dart';

/// The chat feature's single [ChatRepository].
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatRepository(apiClient);
});

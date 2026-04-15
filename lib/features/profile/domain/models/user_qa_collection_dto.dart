import 'package:eros_app/features/profile/domain/models/user_qa_item_dto.dart';

/// DTO for a collection of Q&As for a user
/// Response from POST /users/qa/me/collection
class UserQACollectionDTO {
  final String userId;
  final List<UserQAItemDTO> qas;
  final int totalCount;

  const UserQACollectionDTO({
    required this.userId,
    required this.qas,
    required this.totalCount,
  });

  factory UserQACollectionDTO.fromJson(Map<String, dynamic> json) {
    return UserQACollectionDTO(
      userId: json['userId'] as String,
      qas: (json['qas'] as List)
          .map((item) => UserQAItemDTO.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'qas': qas.map((item) => item.toJson()).toList(),
      'totalCount': totalCount,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserQACollectionDTO &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          _listEquals(qas, other.qas) &&
          totalCount == other.totalCount;

  @override
  int get hashCode =>
      userId.hashCode ^ qas.hashCode ^ totalCount.hashCode;

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'UserQACollectionDTO(userId: $userId, totalCount: $totalCount, qas: ${qas.length} items)';
}

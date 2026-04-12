/// Wrapper for profile fields that can be shown or hidden
/// Matches backend DisplayableField structure
class DisplayableField<T> {
  final T field;
  final bool visible;

  const DisplayableField({
    required this.field,
    this.visible = true,
  });

  /// Create a hidden field
  factory DisplayableField.hidden(T field) {
    return DisplayableField(field: field, visible: false);
  }

  /// Create a visible field
  factory DisplayableField.visible(T field) {
    return DisplayableField(field: field, visible: true);
  }

  /// Copy with new values
  DisplayableField<T> copyWith({
    T? field,
    bool? visible,
  }) {
    return DisplayableField(
      field: field ?? this.field,
      visible: visible ?? this.visible,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson(dynamic Function(T) fieldToJson) {
    return {
      'field': fieldToJson(field),
      'display': visible,
    };
  }

  /// Create from JSON
  factory DisplayableField.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fieldFromJson,
  ) {
    return DisplayableField(
      field: fieldFromJson(json['field']),
      visible: json['display'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayableField<T> &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          visible == other.visible;

  @override
  int get hashCode => field.hashCode ^ visible.hashCode;

  @override
  String toString() => 'DisplayableField(field: $field, display: $visible)';
}

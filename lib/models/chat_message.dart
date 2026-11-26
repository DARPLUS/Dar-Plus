enum ChatMessageRole {
  user,
  assistant;

  String get value => name;

  static ChatMessageRole fromValue(Object? value) {
    return value == 'user' ? ChatMessageRole.user : ChatMessageRole.assistant;
  }
}

class ChatMessage {
  final String id;
  final ChatMessageRole role;
  final String text;
  final DateTime createdAt;
  final List<String> recommendationIds;
  final List<Map<String, dynamic>> recommendations;
  final String? priceEstimate;
  final String? serviceType;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.recommendationIds = const [],
    this.recommendations = const [],
    this.priceEstimate,
    this.serviceType,
  });

  bool get isUser => role == ChatMessageRole.user;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final rawDate = map['createdAt'];
    final createdAt = rawDate is DateTime
        ? rawDate
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    final rawIds = map['recommendationIds'];

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      role: ChatMessageRole.fromValue(map['role']),
      text: map['text']?.toString() ?? '',
      createdAt: createdAt,
      recommendationIds: rawIds is List
          ? rawIds.map((id) => id.toString()).toList()
          : const [],
      priceEstimate: map['priceEstimate']?.toString(),
      serviceType: map['serviceType']?.toString(),
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
    'role': role.value,
    'text': text,
    'recommendationIds': recommendationIds,
    if (priceEstimate != null) 'priceEstimate': priceEstimate,
    if (serviceType != null) 'serviceType': serviceType,
  };
}

class AiConversationSummary {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime updatedAt;

  const AiConversationSummary({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.updatedAt,
  });

  factory AiConversationSummary.fromMap(Map<String, dynamic> map) {
    final rawDate = map['updatedAt'];
    final updatedAt = rawDate is DateTime
        ? rawDate
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();

    return AiConversationSummary(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      lastMessage: map['lastMessage']?.toString() ?? '',
      updatedAt: updatedAt,
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/ai_context_service.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';

class AiAssistantProvider extends ChangeNotifier {
  static const _firestoreTimeout = Duration(seconds: 15);
  static const _contextTimeout = Duration(seconds: 20);

  AiAssistantProvider({
    FirebaseService? firebaseService,
    AiContextService? contextService,
    GeminiService? geminiService,
  }) : _firebaseService = firebaseService ?? FirebaseService(),
       _contextService = contextService ?? AiContextService(),
       _geminiService = geminiService ?? GeminiService();

  final FirebaseService _firebaseService;
  final AiContextService _contextService;
  final GeminiService _geminiService;

  final List<ChatMessage> _messages = [];
  final List<AiConversationSummary> _conversations = [];
  String? _activeConversationId;
  String? _ownerId;
  int _conversationGeneration = 0;
  Object? _errorMessage;
  bool _isSending = false;
  bool _isLoadingHistory = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<AiConversationSummary> get conversations =>
      List.unmodifiable(_conversations);
  String? get activeConversationId => _activeConversationId;
  Object? get errorMessage => _errorMessage;
  bool get isSending => _isSending;
  bool get isLoadingHistory => _isLoadingHistory;

  Future<void> loadConversations() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _setError(StateError('Connectez-vous pour accéder à Dar Plus AI.'));
      return;
    }
    if (_ownerId != userId) {
      _messages.clear();
      _conversations.clear();
      _activeConversationId = null;
      _ownerId = userId;
    }

    _isLoadingHistory = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final items = await _firebaseService.streamAiConversations().first;
      _conversations
        ..clear()
        ..addAll(items.map(AiConversationSummary.fromMap));
    } catch (error) {
      _setError(error);
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  void startNewConversation() {
    _conversationGeneration++;
    _activeConversationId = null;
    _messages.clear();
    _errorMessage = null;
    _isLoadingHistory = false;
    notifyListeners();
  }

  Future<void> openConversation(String conversationId) async {
    final generation = ++_conversationGeneration;
    _isLoadingHistory = true;
    _errorMessage = null;
    _activeConversationId = conversationId;
    _messages.clear();
    notifyListeners();
    try {
      final rawMessages = await _firebaseService
          .streamAiMessages(conversationId)
          .first;
      if (generation != _conversationGeneration) return;
      final loaded = rawMessages.map(ChatMessage.fromMap).toList();
      final recommendationIds = loaded
          .expand((message) => message.recommendationIds)
          .toSet()
          .toList();
      final professionals = await _contextService.loadRecommendations(
        recommendationIds,
      );
      if (generation != _conversationGeneration) return;
      final professionalsById = {
        for (final pro in professionals) pro['id'].toString(): pro,
      };

      _messages.addAll(
        loaded.map(
          (message) => ChatMessage(
            id: message.id,
            role: message.role,
            text: message.text,
            createdAt: message.createdAt,
            recommendationIds: message.recommendationIds,
            recommendations: message.recommendationIds
                .map((id) => professionalsById[id])
                .whereType<Map<String, dynamic>>()
                .toList(),
            priceEstimate: message.priceEstimate,
            serviceType: message.serviceType,
          ),
        ),
      );
    } catch (error) {
      if (generation == _conversationGeneration) _setError(error);
    } finally {
      if (generation == _conversationGeneration) {
        _isLoadingHistory = false;
        notifyListeners();
      }
    }
  }

  Future<void> sendMessage(
    String text, {
    required String languageCode,
    String? userLocation,
  }) async {
    final messageText = text.trim();
    if (messageText.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _setError(StateError('Connectez-vous pour utiliser Dar Plus AI.'));
      return;
    }
    if (_ownerId != user.uid) {
      _conversationGeneration++;
      _messages.clear();
      _conversations.clear();
      _activeConversationId = null;
      _ownerId = user.uid;
    }
    final generation = _conversationGeneration;
    final responseLanguageCode = AiContextService.detectLanguageCode(
      messageText,
      fallbackLanguageCode: languageCode,
    );

    final previousMessages = List<ChatMessage>.of(_messages);
    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: ChatMessageRole.user,
      text: messageText,
      createdAt: DateTime.now(),
    );
    _messages.add(userMessage);
    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final String conversationId =
          _activeConversationId ??
          await _withTimeout(
            _firebaseService.createAiConversation(
              title: messageText.length > 60
                  ? '${messageText.substring(0, 57)}…'
                  : messageText,
            ),
            _firestoreTimeout,
          );
      if (generation == _conversationGeneration) {
        _activeConversationId = conversationId;
      }
      await _withTimeout(
        _firebaseService.addAiConversationMessage(
          conversationId: conversationId,
          role: ChatMessageRole.user.value,
          text: messageText,
          recommendationIds: const [],
        ),
        _firestoreTimeout,
      );

      final context = await _withTimeout(
        _contextService.buildContext(
          message: messageText,
          languageCode: responseLanguageCode,
          userLocation: userLocation,
        ),
        _contextTimeout,
      );
      final answer = await _geminiService.reply(
        message: messageText,
        languageCode: responseLanguageCode,
        verifiedContext: context.promptContext,
        previousMessages: previousMessages,
      );
      final assistantMessage = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: ChatMessageRole.assistant,
        text: answer,
        createdAt: DateTime.now(),
        recommendationIds: context.recommendations
            .map((pro) => pro['id'].toString())
            .toList(),
        recommendations: context.recommendations,
        priceEstimate: context.priceEstimate,
        serviceType: context.serviceType,
      );
      if (generation == _conversationGeneration) {
        _messages.add(assistantMessage);
        notifyListeners();
      }

      await _withTimeout(
        _firebaseService.addAiConversationMessage(
          conversationId: conversationId,
          role: ChatMessageRole.assistant.value,
          text: answer,
          recommendationIds: assistantMessage.recommendationIds,
          priceEstimate: context.priceEstimate,
          serviceType: context.serviceType,
        ),
        _firestoreTimeout,
      );
      await loadConversations();
    } catch (error) {
      if (generation == _conversationGeneration) _setError(error);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(Object error) {
    _errorMessage = error;
    notifyListeners();
  }

  Future<T> _withTimeout<T>(Future<T> future, Duration duration) {
    return future.timeout(
      duration,
      onTimeout: () => throw const AiServiceUnavailableException(),
    );
  }
}

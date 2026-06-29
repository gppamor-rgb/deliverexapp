import 'package:flutter/foundation.dart';

import '../services/chatbot_service.dart';

enum SuggestionState { main, account, quick }

class ChatMessage {
  const ChatMessage({
    required this.role,
    this.content = '',
    this.kind = 'text',
    this.body,
    this.isError = false,
    this.timestamp,
  });

  final String role;
  final String content;
  final String kind;
  final Map<String, dynamic>? body;
  final bool isError;
  final DateTime? timestamp;
}

class ChatbotProvider extends ChangeNotifier {
  ChatbotProvider._({ChatbotService? service})
    : _service = service ?? ChatbotService();

  static final ChatbotProvider instance = ChatbotProvider._();

  final ChatbotService _service;
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  String? _lastSent;
  SuggestionState _suggestionState = SuggestionState.main;
  SuggestionState? _pendingState;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  SuggestionState get suggestionState => _suggestionState;

  void setSuggestionState(SuggestionState state) {
    _suggestionState = state;
    _pendingState = null;
    notifyListeners();
  }

  void addMessage(ChatMessage msg) {
    _messages.add(msg);
    notifyListeners();
  }

  void setSuggestionAfter({
    required SuggestionState state,
    ChatMessage? userMsg,
    ChatMessage? assistantMsg,
  }) {
    if (userMsg != null) _messages.add(userMsg);
    if (assistantMsg != null) _messages.add(assistantMsg);
    _suggestionState = state;
    _pendingState = null;
    notifyListeners();
  }

  Future<void> sendMessage(String text, {SuggestionState? nextState}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    _pendingState = nextState;
    _lastSent = trimmed;
    _messages.add(
      ChatMessage(role: 'user', content: trimmed, timestamp: DateTime.now()),
    );
    _loading = true;
    notifyListeners();

    try {
      final history = _messages
          .where((m) => !m.isError)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final reply = await _service.sendMessage(trimmed, history);

      _messages.add(
        ChatMessage(
          role: 'assistant',
          content: reply,
          timestamp: DateTime.now(),
        ),
      );
    } catch (err) {
      _messages.add(
        ChatMessage(
          role: 'assistant',
          content: err.toString(),
          isError: true,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _loading = false;
      if (_pendingState != null) {
        _suggestionState = _pendingState!;
        _pendingState = null;
      }
      notifyListeners();
    }
  }

  void retry() {
    if (_lastSent != null) {
      final text = _lastSent!;
      _lastSent = null;
      sendMessage(text);
    }
  }

  void clear() {
    _messages.clear();
    _loading = false;
    _lastSent = null;
    _suggestionState = SuggestionState.main;
    _pendingState = null;
    notifyListeners();
  }
}

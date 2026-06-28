import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../providers/chatbot_provider.dart';
import '../services/tracking_service.dart';
import 'customer_forgot_password_screen.dart';
import 'login_screen.dart';
import 'tracking_screen.dart';

const _mainOptions = [
  'Track My Delivery',
  'What is a Tracking ID?',
  'Account Help',
  'Contact Support',
  'General Questions',
];

const _accountOptions = [
  'Create Account',
  'Login',
  'Link Delivery',
  'Forgot Password',
];

const _quickOptions = [
  'Track Another Delivery',
  'Contact Support',
  'Return to Menu',
];

const _supportEmail = 'deliverex.support@gmail.com';
const _supportPhone = '(+63) 995-582-0222';
const _welcomeMessage =
    'Hello! I can help you with tracking deliveries, Tracking IDs, account assistance, support contacts, and general Deliverex questions.';
const _trackingIdPrompt =
    'Please enter your Tracking ID.\n\nExample:\nTRK-ABC123\nor\nDLX-2026-001';
const _trackingIdFaq =
    'A Tracking ID is a unique reference number assigned to your delivery. Use it to view delivery status, timeline updates, and Proof of Delivery when available.';

const _faqItems = [
  (
    'What does Deliverex do?',
    'Deliverex manages dispatching, tracking, POD capture, and delivery records.',
  ),
  (
    'How do I track my delivery?',
    'Enter your Tracking ID on the tracking page or use Track My Delivery here.',
  ),
  (
    'How do I link a delivery to my account?',
    'Deliveries assigned to your company may appear automatically after sign-in. If a delivery is missing, contact support with your Tracking ID.',
  ),
  (
    'How do I create an account?',
    'Company accounts are created by a Deliverex administrator. Customer self-signup is available when enabled for your account.',
  ),
  (
    'Where do I request services?',
    'You can request assistance through the support contact form and service channels.',
  ),
  (
    'What do delivery statuses mean?',
    'See the delivery status guide for Assigned, En Route, Arrived, and Completed.',
  ),
];

const _statusGuide = [
  ('Assigned', 'Driver assigned.', Color(0xFF2563EB)),
  ('En Route', 'Delivery is currently in transit.', Color(0xFF0891B2)),
  ('Arrived', 'Driver has reached destination.', Color(0xFFD97706)),
  ('Completed', 'Delivery has been successfully completed.', Color(0xFF059669)),
];

String _sectionLabel(SuggestionState state) {
  return switch (state) {
    SuggestionState.main => 'Choose an option',
    SuggestionState.account => 'Account options',
    SuggestionState.quick => 'Quick actions',
  };
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key, this.embedded = false, this.onClose});

  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _trackingService = TrackingService();
  bool _awaitingTrackInput = false;
  bool _checkingTracking = false;

  @override
  void initState() {
    super.initState();
    _seedWelcomeIfNeeded();
  }

  void _seedWelcomeIfNeeded() {
    final provider = ChatbotProvider.instance;
    if (provider.messages.isNotEmpty) return;
    provider.addMessage(
      ChatMessage(
        role: 'assistant',
        content: _welcomeMessage,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSuggestionTap(String label) {
    HapticFeedback.lightImpact();
    final provider = ChatbotProvider.instance;

    final userMsg = ChatMessage(
      role: 'user',
      content: label,
      timestamp: DateTime.now(),
    );

    switch (label) {
      case 'Track My Delivery':
      case 'Track Another Delivery':
        setState(() => _awaitingTrackInput = true);
        provider.setSuggestionAfter(
          state: SuggestionState.quick,
          userMsg: userMsg,
          assistantMsg: ChatMessage(
            role: 'assistant',
            content: _trackingIdPrompt,
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'What is a Tracking ID?':
        provider.setSuggestionAfter(
          state: SuggestionState.quick,
          userMsg: userMsg,
          assistantMsg: ChatMessage(
            role: 'assistant',
            content: _trackingIdFaq,
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'Account Help':
        provider.setSuggestionState(SuggestionState.account);
        provider.addMessage(userMsg);
        provider.addMessage(
          ChatMessage(
            role: 'assistant',
            content:
                'Choose an account topic: Create Account, Login, Link Delivery, or Forgot Password.',
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'Contact Support':
        provider.setSuggestionAfter(
          state: SuggestionState.quick,
          userMsg: userMsg,
          assistantMsg: ChatMessage(
            role: 'assistant',
            content: 'You can contact support through these channels:',
            timestamp: DateTime.now(),
          ),
        );
        provider.addMessage(
          ChatMessage(
            role: 'assistant',
            kind: 'contact',
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'General Questions':
        provider.setSuggestionAfter(
          state: SuggestionState.quick,
          userMsg: userMsg,
          assistantMsg: ChatMessage(
            role: 'assistant',
            kind: 'faq',
            timestamp: DateTime.now(),
          ),
        );
        provider.addMessage(
          ChatMessage(
            role: 'assistant',
            kind: 'status_guide',
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'Create Account':
        provider.setSuggestionAfter(
          state: SuggestionState.quick,
          userMsg: userMsg,
          assistantMsg: ChatMessage(
            role: 'assistant',
            content:
                'Customer accounts are created through the Deliverex team or your company setup. Contact support if you need account access.',
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'Login':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
        provider.setSuggestionState(SuggestionState.quick);
        provider.addMessage(userMsg);
        break;

      case 'Link Delivery':
        provider.setSuggestionAfter(
          state: SuggestionState.quick,
          userMsg: userMsg,
          assistantMsg: ChatMessage(
            role: 'assistant',
            content:
                'Deliveries assigned to your company may appear automatically after sign-in. If a delivery is missing, contact support with your Tracking ID so the team can verify it.',
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'Forgot Password':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CustomerForgotPasswordScreen(),
          ),
        );
        provider.setSuggestionState(SuggestionState.quick);
        provider.addMessage(userMsg);
        break;

      case 'Return to Menu':
        provider.setSuggestionState(SuggestionState.main);
        provider.addMessage(userMsg);
        provider.addMessage(
          ChatMessage(
            role: 'assistant',
            content: _welcomeMessage,
            timestamp: DateTime.now(),
          ),
        );
        break;
    }
  }

  Future<void> _handleTrackingLookup(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      ChatbotProvider.instance.addMessage(
        ChatMessage(
          role: 'assistant',
          content: _trackingIdPrompt,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    setState(() => _checkingTracking = true);

    try {
      final result = await _trackingService.lookup(trimmed);
      ChatbotProvider.instance.addMessage(
        ChatMessage(
          role: 'assistant',
          kind: 'tracking',
          body: {
            'code': result.trackingCode.isNotEmpty
                ? result.trackingCode
                : trimmed,
            'status': result.statusLabel,
            'lastUpdated': result.lastUpdated ?? 'Not yet available',
            'prefill': trimmed,
          },
          timestamp: DateTime.now(),
        ),
      );
    } catch (err) {
      ChatbotProvider.instance.addMessage(
        ChatMessage(
          role: 'assistant',
          content: err is TrackingLookupException
              ? err.message
              : 'Unable to check this Tracking ID right now. Please try again.',
          isError: true,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _awaitingTrackInput = false;
          _checkingTracking = false;
        });
      }
    }
  }

  void _onSend() {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();

    if (_awaitingTrackInput) {
      ChatbotProvider.instance.addMessage(
        ChatMessage(role: 'user', content: text, timestamp: DateTime.now()),
      );
      _handleTrackingLookup(text);
      return;
    }

    final lower = text.toLowerCase().trim();
    if (lower.contains('track') || lower.contains('delivery status')) {
      setState(() => _awaitingTrackInput = true);
      ChatbotProvider.instance.addMessage(
        ChatMessage(role: 'user', content: text, timestamp: DateTime.now()),
      );
      ChatbotProvider.instance.addMessage(
        ChatMessage(
          role: 'assistant',
          content: _trackingIdPrompt,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    ChatbotProvider.instance.sendMessage(text);
  }

  void _clearConversation() {
    ChatbotProvider.instance.clear();
    _focusNode.unfocus();
    setState(() => _awaitingTrackInput = false);
    _seedWelcomeIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChatbotProvider.instance,
      builder: (context, _) {
        final provider = ChatbotProvider.instance;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
        final content = _buildChatContent(provider);
        if (widget.embedded) {
          return Material(color: AppColors.background, child: content);
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Deliverex Assistant'),
            centerTitle: true,
            actions: [
              if (provider.messages.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Clear conversation',
                  onPressed: _clearConversation,
                ),
            ],
          ),
          backgroundColor: AppColors.background,
          body: content,
        );
      },
    );
  }

  Widget _buildChatContent(ChatbotProvider provider) {
    return Column(
      children: [
        if (widget.embedded) _buildSheetHeader(provider),
        Expanded(
          child: provider.messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  itemCount:
                      provider.messages.length +
                      ((provider.loading || _checkingTracking) ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= provider.messages.length) {
                      return const _TypingIndicator();
                    }
                    return _buildMessage(provider.messages[index]);
                  },
                ),
        ),
        _buildSuggestionChips(),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildSheetHeader(ChatbotProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Deliverex Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Online',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (provider.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear conversation',
              color: Colors.white,
              onPressed: _clearConversation,
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close assistant',
            color: Colors.white,
            onPressed: widget.onClose ?? () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Deliverex Assistant',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask me about tracking deliveries, account help, services, or anything about Deliverex.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    final isUser = msg.role == 'user';

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.text.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      msg.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    if (msg.timestamp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(msg.timestamp!),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            const _Avatar(role: 'user'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _Avatar(role: 'assistant'),
              const SizedBox(width: 10),
              Flexible(child: _buildAssistantContent(msg)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantContent(ChatMessage msg) {
    if (msg.content.isNotEmpty && msg.kind == 'text') {
      return _TextBubble(text: msg.content, timestamp: msg.timestamp);
    }

    return switch (msg.kind) {
      'tracking' => _TrackingCard(data: msg.body ?? const {}),
      'contact' => const _ContactCard(),
      'faq' => const _FaqCard(),
      'status_guide' => const _StatusGuideCard(),
      _ => _TextBubble(text: msg.content, timestamp: msg.timestamp),
    };
  }

  Widget _buildSuggestionChips() {
    final provider = ChatbotProvider.instance;
    final state = provider.suggestionState;
    final options = switch (state) {
      SuggestionState.main => _mainOptions,
      SuggestionState.account => _accountOptions,
      SuggestionState.quick => _quickOptions,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              _sectionLabel(state),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((label) => _buildChip(label, state)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, SuggestionState state) {
    final (Color bg, Color border, Color text) = switch (state) {
      SuggestionState.account => (
        const Color(0xFFF5F3FF),
        const Color(0xFFC4B5FD),
        const Color(0xFF5B21B6),
      ),
      SuggestionState.quick => (
        AppColors.surface,
        AppColors.border,
        AppColors.text,
      ),
      SuggestionState.main => (
        AppColors.surface,
        AppColors.primary,
        AppColors.primary,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _onSuggestionTap(label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 10,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _onSend(),
              decoration: InputDecoration(
                hintText: _awaitingTrackInput
                    ? 'Enter Tracking ID...'
                    : 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _onSend,
              icon: const Icon(Icons.send_rounded, size: 20),
              color: Colors.white,
              splashRadius: 22,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isAssistant = role == 'assistant';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isAssistant
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: isAssistant
          ? const Icon(
              Icons.smart_toy_outlined,
              size: 20,
              color: AppColors.primary,
            )
          : const Icon(Icons.person_outline, size: 20, color: AppColors.accent),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.text, this.timestamp});

  final String text;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 4),
            Text(
              _fmtTime(timestamp!),
              style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$hour:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? "PM" : "AM"}';
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Avatar(role: 'assistant'),
          SizedBox(width: 10),
          _TypingBubble(),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                Opacity(
                  opacity:
                      0.35 + (((_controller.value + (i * 0.22)) % 1.0) * 0.65),
                  child: const _TypingDot(),
                ),
                if (i < 2) const SizedBox(width: 5),
              ],
              const SizedBox(width: 10),
              const Text(
                'Checking delivery details...',
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.mutedText,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── Rich Card Widgets ───────────────────────────────────────────────────────

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Delivery Result',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                ),
              ),
              _StatusBadge(label: status),
            ],
          ),
          const SizedBox(height: 14),
          _KvRow(label: 'Tracking ID', value: data['code'] as String? ?? ''),
          const SizedBox(height: 8),
          _KvRow(
            label: 'Last Updated',
            value: data['lastUpdated'] as String? ?? '',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrackingScreen(
                      prefillTracking: data['prefill'] as String?,
                      showBackButton: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Tracking Page'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _colorFor(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('assigned')) return const Color(0xFF2563EB);
    if (lower.contains('en route') || lower.contains('transit')) {
      return const Color(0xFF0891B2);
    }
    if (lower.contains('arrived')) return const Color(0xFFD97706);
    if (lower.contains('complete') || lower.contains('deliver')) {
      return const Color(0xFF059669);
    }
    return AppColors.primary;
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Support',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => launchUrl(Uri.parse('mailto:$_supportEmail')),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _supportEmail,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => launchUrl(Uri.parse('tel:+639955820222')),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _supportPhone,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () =>
                launchUrl(Uri.parse('https://deliverexapp.com/customer')),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open Contact Form'),
          ),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'General Questions (FAQ)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          for (final (q, a) in _faqItems) ...[
            Text(
              q,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              a,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _StatusGuideCard extends StatelessWidget {
  const _StatusGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Status Guide',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          for (final (label, desc, tone) in _statusGuide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

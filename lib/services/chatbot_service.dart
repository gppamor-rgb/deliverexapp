import 'dart:math';

class ChatbotService {
  ChatbotService({this.useMock = true});

  bool useMock;
  final _random = Random();

  Future<String> sendMessage(String message, List<Map<String, String>> history) async {
    if (useMock) {
      await Future.delayed(Duration(milliseconds: 600 + _random.nextInt(900)));
      return _mockReply(message);
    }
    return _realRequest(message, history);
  }

  Future<String> _realRequest(String message, List<Map<String, String>> history) async {
    throw UnimplementedError('Backend chatbot endpoint not yet connected.');
  }

  String _mockReply(String message) {
    final lower = message.toLowerCase().trim();

    if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('hey') ||
        lower.contains('good morning') ||
        lower.contains('good evening')) {
      return _pick([
        "Hi there! I'm the Deliverex Assistant. How can I help you today?",
        'Hello! How can I assist you with your delivery needs?',
        'Hey! What can I help you with?',
      ]);
    }

    if (lower.contains('track') ||
        lower.contains('delivery') ||
        lower.contains('order') ||
        lower.contains('where is') ||
        lower.contains('status')) {
      return _pick([
        "I'd be happy to help you track a delivery. Could you please provide your Job Order ID or tracking code?",
        'Sure! Please share your Job Order ID so I can look up the delivery status for you.',
        "Let me check the delivery status. What's your tracking code or Job Order ID?",
      ]);
    }

    if (lower.contains('job order') || lower.contains('what is') && lower.contains('id')) {
      return _pick([
        'A Job Order ID is a unique code assigned to every delivery request in our system. You can find it in your booking confirmation email or on your account dashboard.',
        "It's a unique identifier for your delivery. You'll receive it when you create a job order through our platform.",
      ]);
    }

    if (lower.contains('account') ||
        lower.contains('sign up') ||
        lower.contains('register') ||
        lower.contains('create')) {
      return _pick([
        'To create an account, go to the Start Screen and tap "Sign Up as Customer". You can also log in if you already have an account.',
        "You can create a customer account by tapping the sign-up option on the main screen. If you're having trouble, our support team is happy to help!",
      ]);
    }

    if (lower.contains('login') || lower.contains('sign in') || lower.contains('log in')) {
      return _pick([
        'You can log in using your registered email and password from the Login screen. If you forgot your password, contact support and we can help you recover access.',
        'Head to the Login screen from the main page. Use the email and password you registered with.',
      ]);
    }

    if (lower.contains('forgot') ||
        lower.contains('password') ||
        lower.contains('reset')) {
      return _pick([
        "If you've forgotten your password, please reach out to our support team at deliverex.support@gmail.com and we'll help you regain access to your account.",
        'No worries! Contact our support team and they can assist you with password recovery.',
      ]);
    }

    if (lower.contains('support') ||
        lower.contains('contact') ||
        lower.contains('email') ||
        lower.contains('phone') ||
        lower.contains('help')) {
      return _pick([
        'You can reach our support team at deliverex.support@gmail.com or call (+63) 995-582-0222. We typically respond within a few hours.',
        "For support, email us at deliverex.support@gmail.com or give us a call at (+63) 995-582-0222. We're happy to help!",
      ]);
    }

    if (lower.contains('price') ||
        lower.contains('cost') ||
        lower.contains('rate') ||
        lower.contains('fee') ||
        lower.contains('how much')) {
      return _pick([
        'For pricing information, please contact our sales team or request a quote through the support form. Rates vary depending on distance, vehicle type, and delivery requirements.',
        "Pricing depends on your specific delivery needs. Reach out to our support team and they'll provide a detailed quote.",
      ]);
    }

    if (lower.contains('service') ||
        lower.contains('what do you') ||
        lower.contains('offer') ||
        lower.contains('capabilities')) {
      return _pick([
        'Deliverex provides fleet dispatch, real-time delivery tracking, OCR documentation, and proof-of-delivery management for businesses of all sizes.',
        'We offer fleet dispatch management, delivery tracking, document OCR, and POD solutions. What would you like to know more about?',
      ]);
    }

    if (lower.contains('driver') || lower.contains('rider') || lower.contains('courier')) {
      return _pick([
        'Our drivers are assigned through our dispatch system. If you need to contact a driver regarding an active delivery, please reach out to support.',
        'Drivers are dispatched based on availability and proximity. For driver-specific concerns, contact our support team.',
      ]);
    }

    if (lower.contains('thank') || lower.contains('thanks') || lower.contains('appreciate')) {
      return _pick([
        "You're welcome! If you have any more questions, feel free to ask.",
        "Happy to help! Don't hesitate to reach out if you need anything else.",
        'Anytime! Let me know if there is anything else I can assist with.',
      ]);
    }

    if (lower.contains('bye') ||
        lower.contains('goodbye') ||
        lower.contains('see you')) {
      return _pick([
        'Goodbye! Feel free to come back anytime you need assistance.',
        'Take care! If you need help later, I will be right here.',
        'See you! Wishing you a great day.',
      ]);
    }

    return _pick([
      "I'm not sure I understand. Could you rephrase that? I can help with tracking deliveries, account questions, and general information about Deliverex services.",
      "I didn't quite catch that. You can ask me about delivery tracking, account help, support contact, or anything about Deliverex services.",
      "Hmm, I'm not sure about that. Try asking about tracking a delivery, creating an account, or getting support.",
    ]);
  }

  String _pick(List<String> options) {
    return options[_random.nextInt(options.length)];
  }
}

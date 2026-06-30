import 'dart:math';

class ChatbotService {
  ChatbotService({this.useMock = true});

  bool useMock;
  final _random = Random();

  Future<String> sendMessage(
    String message,
    List<Map<String, String>> history,
  ) async {
    if (useMock) {
      await Future.delayed(Duration(milliseconds: 600 + _random.nextInt(900)));
      return _mockReply(message);
    }
    return _realRequest(message, history);
  }

  Future<String> _realRequest(
    String message,
    List<Map<String, String>> history,
  ) async {
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
        "Hello! I'm the Deliverex Assistant. How can I help you today?",
        'Hi there! Ask me about tracking, concerns, accounts, or how Deliverex works.',
        'Hey! How can I assist you with your delivery needs today?',
      ]);
    }

    if (lower.contains('track') ||
        lower.contains('delivery') ||
        lower.contains('order') ||
        lower.contains('where is') ||
        lower.contains('status')) {
      return _pick([
        'To track a delivery, enter your Tracking ID (e.g. TRK-ABC123 or DLX-2026-001). You can paste the code here, use Track Delivery, or open the public tracking page.',
        "I'd be happy to help you track a delivery. Please provide your Tracking ID (e.g. TRK-ABC123, DLX-2026-001).",
        "Let me check the delivery status. What's your Tracking ID? You'll see the current status, timeline, and proof of delivery when completed.",
      ]);
    }

    if ((lower.contains('what is') && lower.contains('id')) ||
        lower.contains('tracking id') ||
        lower.contains('tracking code') ||
        lower.contains('find tracking') ||
        lower.contains('reference')) {
      return _pick([
        'A Tracking ID is a unique code for your shipment (examples: TRK-ABC123, DLX-2026-001). You receive it via SMS, email, or from your dispatcher. Use it on the tracking page or here in chat to see live status, timeline, and POD when finished.',
        "Your Tracking ID is provided by your dispatcher or logistics team when the shipment is created. Check SMS, email, or your delivery confirmation for codes like TRK-ABC123 or DLX-2026-001.",
      ]);
    }

    if (lower.contains('account') ||
        lower.contains('sign up') ||
        lower.contains('register') ||
        lower.contains('create')) {
      return _pick([
        'Customer accounts are created by a Deliverex administrator or linked when a dispatcher creates a delivery using your email. Sign in with your registered email and password at the customer login page.',
        "If you need customer account access, contact support so the team can help with your company setup. After login you can view linked deliveries and submit concerns.",
      ]);
    }

    if (lower.contains('login') ||
        lower.contains('sign in') ||
        lower.contains('log in')) {
      return _pick([
        'Sign in with your registered email and password at the customer login page. Customer accounts are created by a Deliverex administrator or linked when a dispatcher creates a delivery using your email.',
        'Head to the Login screen from the main page. Use the email and password you registered with. After login you can view linked deliveries, submit concerns, and manage your profile.',
      ]);
    }

    if (lower.contains('forgot') ||
        lower.contains('password') ||
        lower.contains('reset')) {
      return _pick([
        'On the Forgot Password page, enter your account email. If the account exists, we will send a reset link. After resetting, sign in with your new password.',
        'Use Forgot Password on the sign-in page to request a reset link by email. Enter your customer email and we will send a reset link if the account exists.',
      ]);
    }

    if (lower.contains('support') ||
        lower.contains('contact') ||
        lower.contains('email') ||
        lower.contains('phone') ||
        lower.contains('help')) {
      return _pick([
        'You can reach our support team at deliverexapp@gmail.com or call (+63) 995-582-0222. For quick status checks, use Track Delivery or the chat assistant first.',
        "For support, email us at deliverexapp@gmail.com or call (+63) 995-582-0222. You can also submit a concern through the contact form with your Tracking ID and details.",
      ]);
    }

    if (lower.contains('concern') ||
        lower.contains('inquiry') ||
        lower.contains('complaint') ||
        lower.contains('feedback') ||
        lower.contains('reklamo') ||
        lower.contains('report')) {
      return _pick([
        'You can submit a concern anytime. Use Submit Concern in chat, open the Contact Support form, or email deliverexapp@gmail.com. Concern types: delivery inquiry, complaint, follow-up, general question, or feedback.',
        "To submit a concern, email deliverexapp@gmail.com or use the contact form with your Tracking ID and details. You'll receive a reference number and confirmation email.",
      ]);
    }

    if (lower.contains('inquiry type') ||
        lower.contains('concern type') ||
        lower.contains('complaint type') ||
        (lower.contains('delivery') && lower.contains('inquiry')) ||
        (lower.contains('follow') && lower.contains('up'))) {
      return _pick([
        'Concern types in Deliverex:\n\n• Delivery concern — questions about a specific shipment\n• Complaint — service issues or delays\n• Follow-up — checking on a previous concern\n• General question — how the system works\n• Feedback — suggestions or praise',
        "You can submit these concern types: delivery inquiry, complaint, follow-up, general question, or feedback. Dispatchers and admins review inquiries and can convert them into job orders when needed.",
      ]);
    }

    if (lower.contains('service') ||
        lower.contains('what do you') ||
        lower.contains('offer') ||
        lower.contains('capabilities') ||
        lower.contains('what is deliverex')) {
      return _pick([
        'Deliverex is a fleet dispatch and delivery management platform for construction and site logistics. It connects dispatchers, drivers, managers, and customers for job orders, GPS tracking, Best-Fit driver assignment, OCR document review, and proof of delivery.',
        'We support material hauling (aggregates, sand, gravel), coordinated delivery with company drivers and vehicles, and site preparation logistics support — all tracked from dispatch through completion with delivery records and POD.',
      ]);
    }

    if (lower.contains('best fit') ||
        lower.contains('best-fit') ||
        lower.contains('scoring') ||
        lower.contains('assignment score')) {
      return _pick([
        'Best-Fit helps dispatchers pick the best driver-vehicle pair for a job order. It scores candidates on vehicle type match, availability, workload, and other factors (max 100 points). Dispatchers see explainable scores and can override with a documented reason.',
        "Best-Fit is our intelligent assignment system. It scores driver-vehicle pairs based on vehicle match, availability, workload, and more. Customers benefit from faster, better-matched assignments.",
      ]);
    }

    if (lower.contains('ocr') ||
        lower.contains('document') ||
        lower.contains('scan') ||
        lower.contains('extract') ||
        lower.contains('delivery receipt')) {
      return _pick([
        'Drivers upload delivery documents (e.g. delivery receipts). OCR extracts fields like dimensions, volume, and receipt numbers. Admins review OCR results in a validation panel before approval, reducing manual data entry and errors.',
        "Our OCR system automatically extracts data from delivery documents like dimensions, volume, and receipt numbers. Admins review and validate the extracted data before final approval.",
      ]);
    }

    if (lower.contains('gps') ||
        lower.contains('location') ||
        lower.contains('map') ||
        lower.contains('live track') ||
        lower.contains('real time') ||
        lower.contains('coordinates')) {
      return _pick([
        'Drivers share GPS location during active deliveries. Dispatchers and managers see live positions on the fleet map. Customers see approximate location and status timeline on the tracking page — not exact driver coordinates for privacy.',
        "GPS tracking is available for active deliveries. Dispatchers and managers have full live tracking. Customers see approximate location and status updates on the tracking page for privacy reasons.",
      ]);
    }

    if (lower.contains('delay') ||
        lower.contains('late') ||
        lower.contains('antala') ||
        lower.contains('eta')) {
      return _pick([
        'If a delivery passes its scheduled end time without completing, the system flags a delay. Drivers can report delays with a reason. For urgent issues, submit a concern with your Tracking ID or contact support directly.',
        "Delays are flagged when a delivery passes its scheduled end time. Drivers report delay reasons. Dispatchers and managers see delay alerts. Contact support for urgent delay issues.",
      ]);
    }

    if (lower.contains('pod') ||
        lower.contains('proof of delivery') ||
        lower.contains('proof') ||
        lower.contains('signature') ||
        lower.contains('resibo') ||
        (lower.contains('delivered') && !lower.contains('track'))) {
      return _pick([
        'Proof of Delivery (POD) is captured when a driver completes a delivery — often via signed document OCR, photo, or completion form with receiver name and notes. Once status is Completed, customers can view POD documents on the tracking page if available.',
        "POD is captured at delivery completion via document OCR, photo, or form. Customers can view POD on the tracking page when available. Admins review OCR-extracted data for accuracy.",
      ]);
    }

    if (lower.contains('driver') ||
        lower.contains('rider') ||
        lower.contains('courier')) {
      return _pick([
        'Our drivers are assigned through our dispatch system using Best-Fit scoring. Drivers share GPS during active deliveries and update status throughout the trip. For driver-specific concerns, contact our support team.',
        'Drivers are dispatched based on availability and proximity using the Best-Fit system. They update delivery status and submit POD. If you need to contact a driver, please reach out to support.',
      ]);
    }

    if (lower.contains('dispatcher') ||
        lower.contains('dispatch') ||
        lower.contains('assign driver') ||
        lower.contains('job order') ||
        lower.contains('fleet dispatch')) {
      return _pick([
        'Dispatchers create job orders with pickup/drop-off, cargo details, and customer info. They assign drivers and vehicles — manually or via Best-Fit recommendations. They monitor live GPS, handle delays, review inquiries, and update delivery status throughout the trip.',
        "A job order is a delivery request with customer details, pickup and drop-off locations, cargo requirements, schedule, and priority. Each job order gets a Tracking ID and moves through delivery statuses until Completed or Cancelled.",
      ]);
    }

    if (lower.contains('customer portal') ||
        (lower.contains('my') &&
            (lower.contains('order') || lower.contains('delivery'))) ||
        lower.contains('dashboard')) {
      return _pick([
        'The customer portal shows your linked deliveries, tracking history, and submitted concerns. After login you can view orders, link new deliveries, edit your profile, and manage company users if you are a company contact.',
        "Your customer dashboard displays linked deliveries and tracking history. Sign in to view orders, link new deliveries, and manage your profile.",
      ]);
    }

    if (lower.contains('company') &&
        (lower.contains('account') ||
            lower.contains('user') ||
            lower.contains('organization'))) {
      return _pick([
        'Companies in Deliverex group customer users under one organization. Admins create company records and invite customer users. Company contacts can view shared deliveries and manage company users from the customer portal.',
        "Company accounts are managed by Deliverex administrators. Company contacts can view shared deliveries and manage users after activation via email invitation.",
      ]);
    }

    if (lower.contains('role') ||
        lower.contains('admin') ||
        lower.contains('manager') ||
        lower.contains('permissions') ||
        lower.contains('who can')) {
      return _pick([
        'Deliverex roles:\n\n• Admin — users, companies, vehicles, drivers, OCR review, audit logs\n• Dispatcher — job orders, assignments, GPS, inquiries\n• Manager — analytics, reports, fleet overview\n• Driver — mobile assignments, status updates, POD upload\n• Customer — track deliveries, portal, concerns',
        "User roles in Deliverex: Admin (full control), Dispatcher (job orders and GPS), Manager (analytics), Driver (mobile delivery updates), Customer (tracking and concerns).",
      ]);
    }

    if (lower.contains('price') ||
        lower.contains('cost') ||
        lower.contains('rate') ||
        lower.contains('fee') ||
        lower.contains('how much')) {
      return _pick([
        'For pricing information, please contact our sales team or request a quote through the support form. Rates vary depending on distance, vehicle type, and delivery requirements.',
        "Pricing depends on your specific delivery needs. Reach out to our support team at deliverexapp@gmail.com and they will provide a detailed quote.",
      ]);
    }

    if (lower.contains('link delivery') ||
        lower.contains('link account') ||
        lower.contains('connect') ||
        (lower.contains('not') && lower.contains('show'))) {
      return _pick([
        'Deliveries for your company are usually linked automatically when a dispatcher creates them with your email. If a shipment is not visible after sign-in, open Link Delivery and enter the Tracking ID. The shipment email must match your account email.',
        "Missing a delivery? Link it using the Tracking ID. Deliveries are automatically linked when created with your email. Contact support if you still have issues.",
      ]);
    }

    if (lower.contains('thank') ||
        lower.contains('thanks') ||
        lower.contains('appreciate')) {
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
      "I'm not sure I understand. Could you rephrase that? I can help with tracking deliveries, submitting concerns, account questions, and general information about Deliverex services.",
      "I didn't quite catch that. You can ask me about delivery tracking, submitting concerns, account help, or anything about Deliverex services.",
      "Hmm, I'm not sure about that. Try asking about tracking a delivery, submitting a concern, account help, or getting support.",
    ]);
  }

  String _pick(List<String> options) {
    return options[_random.nextInt(options.length)];
  }
}

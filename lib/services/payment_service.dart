import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentService {
  late Razorpay _razorpay;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Razorpay API keys (Replace with your actual keys)
  static const String keyId = 'YOUR_RAZORPAY_KEY_ID';
  static const String keySecret = 'YOUR_RAZORPAY_KEY_SECRET';

  // Payment amounts (in paise - 1 INR = 100 paise)
  static const int organizerSubscriptionAmount = 99900; // ₹999

  void initialize({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (response) {
      onSuccess(response as PaymentSuccessResponse);
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (response) {
      onFailure(response as PaymentFailureResponse);
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (response) {
      onExternalWallet(response as ExternalWalletResponse);
    });
  }

  // Open payment for organizer subscription
  void openOrganizerSubscription({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
  }) {
    var options = {
      'key': keyId,
      'amount': organizerSubscriptionAmount,
      'name': 'Winniko',
      'description': 'Paid Organizer Subscription',
      'prefill': {'contact': userPhone, 'email': userEmail},
      'theme': {
        'color': '#1B5E20', // Dark green
      },
      'notes': {'userId': userId, 'subscriptionType': 'organizer'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      throw Exception('Failed to open payment: ${e.toString()}');
    }
  }

  // Verify payment and update user status
  Future<void> verifyAndUpdateOrganizerStatus({
    required String userId,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      // In production, verify the signature on your backend server
      // For now, we'll just update the user status

      // Store payment record
      await _firestore.collection('payments').add({
        'userId': userId,
        'paymentId': paymentId,
        'orderId': orderId,
        'signature': signature,
        'amount': organizerSubscriptionAmount,
        'type': 'organizer_subscription',
        'status': 'success',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update user to paid organizer status
      await _firestore.collection('users').doc(userId).update({
        'isPaidOrganizer': true,
        'subscriptionDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to verify payment: ${e.toString()}');
    }
  }

  // Check if user is a paid organizer
  Future<bool> isPaidOrganizer(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.get('isPaidOrganizer') ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get payment history for user
  Future<List<Map<String, dynamic>>> getPaymentHistory(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Failed to get payment history: ${e.toString()}');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}

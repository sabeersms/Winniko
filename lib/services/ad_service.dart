import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Test IDs - Replace with real IDs before release
  static final String _androidBannerId =
      'ca-app-pub-1776878517180392/9079227636';
  static final String _iOSBannerId = 'ca-app-pub-3940256099942544/2934735716';

  static final String _androidInterstitialId =
      'ca-app-pub-1776878517180392/1392309309';
  static final String _iOSInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  // Singleton
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
  }

  String get bannerAdUnitId {
    if (kIsWeb) return '';

    if (kDebugMode) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Test ID
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'ca-app-pub-3940256099942544/2934735716'; // Test ID
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidBannerId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iOSBannerId;
    }
    return '';
  }

  String get interstitialAdUnitId {
    if (kIsWeb) return '';

    if (kDebugMode) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'ca-app-pub-3940256099942544/1033173712'; // Test ID
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'ca-app-pub-3940256099942544/4411468910'; // Test ID
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidInterstitialId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iOSInterstitialId;
    }
    return '';
  }

  BannerAd createBannerAd({required Function() onAdLoaded}) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('Banner Ad loaded successfully');
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );
  }

  void showInterstitialAd({required Function() onAdDismissed}) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onAdDismissed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onAdDismissed(); // Still proceed if ad fails to show
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          onAdDismissed(); // Proceed even if ad fails to load
        },
      ),
    );
  }
}

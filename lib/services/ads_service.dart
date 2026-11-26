import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static const _androidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _iosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const _androidInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _iosInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static String? get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidBannerAdUnitId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosBannerAdUnitId;
    }
    return null;
  }

  static String? get _interstitialAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidInterstitialAdUnitId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosInterstitialAdUnitId;
    }
    return null;
  }

  static bool _isInitialized = false;
  static bool _isLoadingInterstitial = false;
  static InterstitialAd? _interstitialAd;

  static Future<void> initialize() async {
    if (!isSupported) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      _loadInterstitial();
    } catch (error, stackTrace) {
      debugPrint('Google Mobile Ads initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void _loadInterstitial() {
    final adUnitId = _interstitialAdUnitId;
    if (!_isInitialized ||
        _isLoadingInterstitial ||
        _interstitialAd != null ||
        adUnitId == null) {
      return;
    }

    _isLoadingInterstitial = true;
    unawaited(
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoadingInterstitial = false;
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (error) {
            _isLoadingInterstitial = false;
            debugPrint('Test interstitial ad failed to load: $error');
          },
        ),
      ).catchError((Object error, StackTrace stackTrace) {
        _isLoadingInterstitial = false;
        debugPrint('Test interstitial ad request failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  }

  static void showInterstitialIfAvailable({required VoidCallback onComplete}) {
    final ad = _interstitialAd;
    if (ad == null) {
      onComplete();
      return;
    }

    _interstitialAd = null;
    var completed = false;

    void finish() {
      if (completed) return;
      completed = true;
      ad.dispose();
      _loadInterstitial();
      onComplete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Test interstitial ad failed to show: $error');
        finish();
      },
    );

    unawaited(
      ad.show().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Test interstitial ad could not be shown: $error');
        debugPrintStack(stackTrace: stackTrace);
        finish();
      }),
    );
  }
}

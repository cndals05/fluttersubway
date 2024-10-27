import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;
import 'dart:async';

class AdManager {
  static final AdManager _instance = AdManager._internal();

  factory AdManager() {
    return _instance;
  }

  AdManager._internal();

  BannerAd? _bannerAd;
  int _retryAttempt = 0;
  static const int maxRetries = 3; // 최대 재시도 횟수
  static const int retryDelay = 5; // 재시도 간격(초)

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  BannerAd createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Ad loaded successfully');
          _retryAttempt = 0; // 성공하면 재시도 횟수 초기화
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: $error');
          ad.dispose();
          _bannerAd = null;

          if (_retryAttempt < maxRetries) {
            _retryAttempt++;
            print('Retrying ad load attempt $_retryAttempt after $retryDelay seconds');

            // retryDelay초 후에 다시 시도
            Timer(Duration(seconds: retryDelay), () {
              createBannerAd().load();
            });
          } else {
            print('Maximum retry attempts reached');
            _retryAttempt = 0; // 최대 시도 횟수 도달하면 초기화
          }
        },
      ),
    );
    return _bannerAd!;
  }

  Widget? getBannerAdWidget() {
    if (_bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return null;
  }

  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _retryAttempt = 0; // dispose할 때도 재시도 횟수 초기화
  }
}
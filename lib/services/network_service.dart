import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline }

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast();
  Stream<NetworkStatus> get networkStatusStream => _controller.stream;

  void initialize() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _checkStatus(results);
    });
  }

  Timer? _debounceTimer;

  Future<void> _checkStatus(List<ConnectivityResult> results) async {
    bool hasConnectionInterface = results.any(
      (result) => result != ConnectivityResult.none,
    );

    // Cancel any pending offline notification to prevent flicker
    _debounceTimer?.cancel();

    if (hasConnectionInterface) {
      // If we see an interface, immediately report online to recover fast
      _controller.add(NetworkStatus.online);
    } else {
      // If no interface, wait 2 seconds before reporting offline.
      // This filters out brief disconnections during network switches.
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        _controller.add(NetworkStatus.offline);
      });
    }
  }

  Future<bool> get isConnected async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

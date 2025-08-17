import 'package:connectivity_plus/connectivity_plus.dart';

Stream<bool> onlineStream() {
  return Connectivity().onConnectivityChanged.map(
    (r) => r != ConnectivityResult.none,
  );
}

import 'package:flutter/foundation.dart';

class CartNotifier extends ChangeNotifier {
  static final CartNotifier _instance = CartNotifier._internal();
  factory CartNotifier() => _instance;
  CartNotifier._internal();

  void notifyCartChanged() {
    notifyListeners();
  }
}
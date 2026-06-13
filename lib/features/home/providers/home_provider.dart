import 'package:flutter/foundation.dart';

class HomeProvider extends ChangeNotifier {
  String _message = 'Bienvenido';

  String get message => _message;

  void updateMessage(String newMessage) {
    _message = newMessage;
    notifyListeners();
  }
}

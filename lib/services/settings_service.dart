import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const String _serverIpKey = 'server_ip';
  static const String _digitPositionKey = 'digit_position';
  static const String _serverPortKey = 'server_port';
  static const String _glowColorKey = 'glow_color';
  static const String _brightnessKey = 'brightness';

  SettingsService(this._prefs);

  // Server settings
  String get serverIp => _prefs.getString(_serverIpKey) ?? '';
  set serverIp(String value) {
    _prefs.setString(_serverIpKey, value);
    notifyListeners();
  }

  int get serverPort => _prefs.getInt(_serverPortKey) ?? 8080;
  set serverPort(int value) {
    _prefs.setInt(_serverPortKey, value);
    notifyListeners();
  }

  // Client settings
  int get digitPosition => _prefs.getInt(_digitPositionKey) ?? 0;
  set digitPosition(int value) {
    _prefs.setInt(_digitPositionKey, value);
    notifyListeners();
  }

  // Display settings
  Color get glowColor {
    final colorValue = _prefs.getInt(_glowColorKey) ?? 0xFFFF6B00;
    return Color(colorValue);
  }
  set glowColor(Color value) {
    _prefs.setInt(_glowColorKey, value.value);
    notifyListeners();
  }

  double get brightness => _prefs.getDouble(_brightnessKey) ?? 1.0;
  set brightness(double value) {
    _prefs.setDouble(_brightnessKey, value);
    notifyListeners();
  }

  // Helper methods
  String getDigitName(int position) {
    final positions = [
      'Hours - First Digit (Tens)',    // 0
      'Hours - Second Digit (Ones)',   // 1
      'Minutes - First Digit (Tens)',  // 2
      'Minutes - Second Digit (Ones)', // 3
      'Seconds - First Digit (Tens)',  // 4
      'Seconds - Second Digit (Ones)', // 5
    ];
    if (position >= 0 && position < positions.length) {
      return positions[position];
    }
    return 'Unknown position';
  }

  String getShortDigitName(int position) {
    final positions = [
      'H1', // Hours tens
      'H2', // Hours ones
      'M1', // Minutes tens
      'M2', // Minutes ones
      'S1', // Seconds tens
      'S2', // Seconds ones
    ];
    if (position >= 0 && position < positions.length) {
      return positions[position];
    }
    return '?';
  }

  String getDigitExample(int position) {
    final examples = [
      '1 in 12:34:56', // Hours tens
      '2 in 12:34:56', // Hours ones
      '3 in 12:34:56', // Minutes tens
      '4 in 12:34:56', // Minutes ones
      '5 in 12:34:56', // Seconds tens
      '6 in 12:34:56', // Seconds ones
    ];
    if (position >= 0 && position < examples.length) {
      return examples[position];
    }
    return 'Example: ?';
  }

  void resetToDefaults() {
    _prefs.remove(_serverIpKey);
    _prefs.remove(_digitPositionKey);
    _prefs.remove(_serverPortKey);
    _prefs.remove(_glowColorKey);
    _prefs.remove(_brightnessKey);
    notifyListeners();
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_model.dart';

class StorageService {
  static const _keyConsigneLever = 'consigne_lever';
  static const _keyConsigneCoucher = 'consigne_coucher';
  static const _keyAlarms = 'alarms_list';

  static Future<({String lever, String coucher, List<AlarmModel> alarms})> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final lever = prefs.getString(_keyConsigneLever) ?? '06:00';
    final coucher = prefs.getString(_keyConsigneCoucher) ?? '19:00';

    final alarmsJson = prefs.getString(_keyAlarms);
    List<AlarmModel> alarms = [];
    if (alarmsJson != null && alarmsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(alarmsJson);
      alarms = decoded.map((e) => AlarmModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return (lever: lever, coucher: coucher, alarms: alarms);
  }

  static Future<void> saveConsignes(String lever, String coucher) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyConsigneLever, lever);
    await prefs.setString(_keyConsigneCoucher, coucher);
  }

  static Future<void> saveAlarms(List<AlarmModel> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(alarms.map((a) => a.toJson()).toList());
    await prefs.setString(_keyAlarms, encoded);
  }
}

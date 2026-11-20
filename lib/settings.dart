import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

/// Basic per-device preferences shown on the Profile tab.
class AppSettings extends ChangeNotifier {
  String ownerName = '';
  String partnerName = 'Brother';
  bool showPaise = true;
  bool haptics = true;
  ProfitPeriod defaultPeriod = ProfitPeriod.today;

  /// Employee picked on the last sale; empty when no employee.
  String lastSeller = '';

  static const _prefix = 'settings_';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      ownerName = prefs.getString('${_prefix}owner_name') ?? ownerName;
      partnerName = prefs.getString('${_prefix}partner_name') ?? partnerName;
      showPaise = prefs.getBool('${_prefix}show_paise') ?? showPaise;
      haptics = prefs.getBool('${_prefix}haptics') ?? haptics;
      lastSeller = prefs.getString('${_prefix}last_seller') ?? lastSeller;
      final period = prefs.getString('${_prefix}default_period');
      defaultPeriod = ProfitPeriod.values.firstWhere(
        (value) => value.name == period,
        orElse: () => defaultPeriod,
      );
      notifyListeners();
    } catch (_) {
      // Defaults are fine when preferences cannot be read.
    }
  }

  Future<void> update({
    String? ownerName,
    String? partnerName,
    bool? showPaise,
    bool? haptics,
    ProfitPeriod? defaultPeriod,
    String? lastSeller,
  }) async {
    if (ownerName != null) this.ownerName = ownerName.trim();
    if (partnerName != null) {
      final name = partnerName.trim();
      this.partnerName = name.isEmpty ? 'Brother' : name;
    }
    if (showPaise != null) this.showPaise = showPaise;
    if (haptics != null) this.haptics = haptics;
    if (defaultPeriod != null) this.defaultPeriod = defaultPeriod;
    if (lastSeller != null) this.lastSeller = lastSeller;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefix}owner_name', this.ownerName);
    await prefs.setString('${_prefix}partner_name', this.partnerName);
    await prefs.setBool('${_prefix}show_paise', this.showPaise);
    await prefs.setBool('${_prefix}haptics', this.haptics);
    await prefs.setString('${_prefix}last_seller', this.lastSeller);
    await prefs.setString('${_prefix}default_period', this.defaultPeriod.name);
  }
}

final appSettings = AppSettings();

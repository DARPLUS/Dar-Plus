import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/commission_model.dart';
import '../services/commission_service.dart';

class CommissionProvider extends ChangeNotifier {
  CommissionProvider({CommissionService? service})
    : _service = service ?? CommissionService();

  final CommissionService _service;
  StreamSubscription<CommissionSettings>? _settingsSubscription;

  CommissionSettings _settings = const CommissionSettings();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  CommissionSettings get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> loadSettings() async {
    if (_settingsSubscription != null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.ensureDefaultSettings();
      _settingsSubscription = _service.streamSettings().listen(
        (settings) {
          _settings = settings;
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (Object error) {
          _isLoading = false;
          _errorMessage = error.toString();
          notifyListeners();
        },
      );
    } catch (error) {
      _isLoading = false;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<bool> saveSettings({
    required double percentage,
    required bool isActive,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.updateSettings(
        percentage: percentage,
        isActive: isActive,
      );
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';

class ApiEndpoints {
  static const String envApiUrl = String.fromEnvironment('API_URL');

  // Fallbacks
  static const String defaultProductionUrl = 'https://appimeal-api.onrender.com/api';
  static const String emulatorBaseUrl = 'http://10.0.2.2:8000/api';
  static const String wifiBaseUrl = 'http://192.168.0.103:8000/api';
  static const String localBaseUrl = 'http://127.0.0.1:8000/api';

  static String get baseUrl {
    if (envApiUrl.isNotEmpty) {
      return envApiUrl.endsWith('/') ? '${envApiUrl}api' : (envApiUrl.endsWith('/api') ? envApiUrl : '$envApiUrl/api');
    }
    if (kDebugMode) {
      if (kIsWeb) return localBaseUrl;
      return emulatorBaseUrl;
    }
    return defaultProductionUrl;
  }

  static const String login = '/login';
  static const String logout = '/logout';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String me = '/me';
  static const String uploadAvatar = '/profile/avatar';

  static String resolveImageUrl(String? path, {String? customBaseUrl}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final activeUrl = customBaseUrl ?? baseUrl;
    final serverHost = activeUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$serverHost${path.startsWith('/') ? '' : '/'}$path';
  }

  static const String todayStatus = '/lunch/today-status';
  static const String calendar = '/lunch/calendar';
  static const String schedule = '/lunch/schedule';
  static const String cancel = '/lunch/cancel';
  static const String attend = '/lunch/attend';
  static const String myLedger = '/ledger/me';

  static const String cateringSummary = '/dashboard/catering';
  static const String cateringPayments = '/catering/payments';
  static const String cateringEmployeeBreakdown = '/catering/employee-breakdown';
  static const String adminCateringSummary = '/catering/summary';
  static const String todayList = '/lunch/today-list';

  static const String adminSummary = '/dashboard/admin';
  static const String employees = '/employees';
  static const String payments = '/payments';
  static const String settings = '/settings';
  static const String reportsDaily = '/reports/daily';
  static const String reportsMonthly = '/reports/monthly';
  static const String reportsEmployees = '/reports/employees';
  static const String reportsDues = '/reports/dues';
  static const String reportsExport = '/reports/export';
  static const String auditLogs = '/audit-logs';
  static const String notifications = '/notifications';

  static const String adminManageList = '/admin/lunch/manage-list';
  static const String adminManageMeal = '/admin/lunch/manual-entry';
}

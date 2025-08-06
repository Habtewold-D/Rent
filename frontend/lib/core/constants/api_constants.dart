class ApiConstants {
  ApiConstants._();

  // NOTE: For Android emulator use 10.0.2.2, iOS simulator use localhost
  static const String baseUrl = 'http://10.0.2.2:5000';

  // Auth endpoints
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';

  // Matching endpoints (future use)
  static const String joinRoom = '/api/matching/join-room'; // + '/:roomId'
  static const String createGroup = '/api/matching/create-group'; // + '/:roomId'
  static const String myGroups = '/api/matching/my-groups';
  static const String notifications = '/api/matching/notifications';
}

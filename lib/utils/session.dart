import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static String get token    => _p.getString('token')      ?? '';
  static String get baseUrl  => _p.getString('base_url')   ?? '';
  static String get userName => _p.getString('user_name')  ?? '';
  static String get userEmail=> _p.getString('user_email') ?? '';
  static String get userRole => _p.getString('user_role')  ?? '';
  static String get roleName => _p.getString('role_name')  ?? '';
  static String get photoUrl => _p.getString('photo_url')  ?? '';
  static int    get userId   => _p.getInt('user_id')       ?? 0;
  static int    get schoolId => _p.getInt('school_id')     ?? 0;
  static bool   get isLoggedIn => token.isNotEmpty && baseUrl.isNotEmpty;

  static Future<void> save(String base, String tok, Map<String, dynamic> user) async {
    final url = base.endsWith('/') ? base : '$base/';
    await _p.setString('base_url',   url);
    await _p.setString('token',      tok);
    await _p.setInt   ('user_id',    (user['id']        as num?)?.toInt() ?? 0);
    await _p.setString('user_name',  user['name']       as String? ?? '');
    await _p.setString('user_email', user['email']      as String? ?? '');
    await _p.setString('user_role',  user['role']       as String? ?? '');
    await _p.setString('role_name',  user['role_name']  as String? ?? '');
    await _p.setInt   ('school_id',  (user['school_id'] as num?)?.toInt() ?? 0);
    await _p.setString('photo_url',  user['photo_url']  as String? ?? '');
  }

  static Future<void> clear() => _p.clear();
}

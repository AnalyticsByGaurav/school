import 'package:dio/dio.dart';
import '../utils/session.dart';

class Api {
  static Dio? _dio;

  static Dio _build() {
    final base = Session.baseUrl.isNotEmpty
        ? Session.baseUrl
        : 'http://localhost/school/';

    final d = Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));

    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (Session.token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${Session.token}';
        }
        handler.next(options);
      },
    ));
    return d;
  }

  static Dio get _client => _dio ??= _build();

  static void reset() => _dio = null;

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final r = await _client.get(path, queryParameters: params);
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.data is Map) return Map<String, dynamic>.from(e.response!.data as Map);
      return {'success': false, 'message': e.message ?? 'Network error'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final r = await _client.post(path, data: body);
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.data is Map) return Map<String, dynamic>.from(e.response!.data as Map);
      return {'success': false, 'message': e.message ?? 'Network error'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

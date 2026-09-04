import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? dio})
      : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.aladhan.com/v1',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 10),
                headers: const <String, Object?>{
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio dio;
}

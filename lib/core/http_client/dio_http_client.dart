import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import 'package:melavpn/utils/custom_loggers.dart';

class DioHttpClient with InfraLogger {
  final Map<String, Dio> _dio = {};
  DioHttpClient({required Duration timeout, required this.userAgent, required bool debug}) {
    for (var mode in ["proxy", "direct", "both"]) {
      _dio[mode] = Dio(
        BaseOptions(
          connectTimeout: timeout,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: {"User-Agent": userAgent},
        ),
      );
      _dio[mode]!.interceptors.add(
        RetryInterceptor(
          dio: _dio[mode]!,
          retryDelays: [
            const Duration(seconds: 1),
            if (mode == "both") ...[const Duration(seconds: 2), const Duration(seconds: 3)],
          ],
        ),
      );

      _dio[mode]!.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (url) {
            if (mode == "proxy") {
              return "PROXY localhost:$port";
            } else if (mode == "direct") {
              return "DIRECT";
            } else {
              final bootstrap = _bootstrapProxyAddr;
              if (bootstrap.isNotEmpty) {
                // socks5:host:port → SOCKS host:port; otherwise → PROXY host:port
                final pacBootstrap = bootstrap.startsWith('socks5:')
                    ? 'SOCKS ${bootstrap.substring(7)}'
                    : 'PROXY $bootstrap';
                return "PROXY localhost:$port; $pacBootstrap; DIRECT";
              }
              return "PROXY localhost:$port; DIRECT";
            }
          };
          return client;
        },
      );
    }

    if (debug) {
      // _dio.interceptors.add(LoggyDioInterceptor(requestHeader: true));
    }
  }

  int port = 0;
  String _bootstrapProxyAddr = '';

  void setBootstrapProxy(String addr) {
    _bootstrapProxyAddr = addr;
  }

  String userAgent;
  // bool isPortOpen(String host, int port, {Duration timeout = const Duration(milliseconds: 200)}) async{
  //   try {
  //     Socket.connect(host, port, timeout: timeout).then((socket) {
  //       socket.destroy();
  //     });
  //     return true;
  //   } on SocketException catch (_) {
  //     return false;
  //   } catch (_) {
  //     return false;
  //   }
  // }
  Future<bool> isPortOpen(String host, int port, {Duration timeout = const Duration(milliseconds: 200)}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void setProxyPort(int port) {
    this.port = port;
    loggy.debug("setting proxy port: [$port]");
  }

  Future<Response<T>> get<T>(
    String url, {
    CancelToken? cancelToken,
    String? userAgent,
    ({String username, String password})? credentials,
    bool proxyOnly = false,
    Map<String, String>? extraHeaders,
  }) async {
    final mode = proxyOnly
        ? "proxy"
        : (await isPortOpen("127.0.0.1", port) || _bootstrapProxyAddr.isNotEmpty)
        ? "both"
        : "direct";
    final dio = _dio[mode]!;

    return dio.get<T>(
      url,
      cancelToken: cancelToken,
      options: _options(url, userAgent: userAgent, credentials: credentials, extraHeaders: extraHeaders),
    );
  }

  Future<Response> download(
    String url,
    String path, {
    CancelToken? cancelToken,
    String? userAgent,
    ({String username, String password})? credentials,
    bool proxyOnly = false,
    bool directOnly = false,
    bool bothMode = false,
    Map<String, String>? extraHeaders,
    ProgressCallback? onReceiveProgress,
    Duration? receiveTimeout = const Duration(minutes: 10),
  }) async {
    final mode = proxyOnly
        ? "proxy"
        : directOnly
        ? "direct"
        : (bothMode || await isPortOpen("127.0.0.1", port) || _bootstrapProxyAddr.isNotEmpty)
        ? "both"
        : "direct";
    final dio = _dio[mode]!;
    final opts = _options(url, userAgent: userAgent, credentials: credentials, extraHeaders: extraHeaders);
    return dio.download(
      url,
      path,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      options: opts.copyWith(receiveTimeout: receiveTimeout),
    );
  }

  Options _options(String url, {String? userAgent, ({String username, String password})? credentials, Map<String, String>? extraHeaders}) {
    final uri = Uri.parse(url);

    String? userInfo;
    if (credentials != null) {
      userInfo = "${credentials.username}:${credentials.password}";
    } else if (uri.userInfo.isNotEmpty) {
      userInfo = uri.userInfo;
    }

    String? basicAuth;
    if (userInfo != null) {
      basicAuth = "Basic ${base64.encode(utf8.encode(userInfo))}";
    }

    return Options(
      headers: {
        if (userAgent != null) "User-Agent": userAgent,
        if (basicAuth != null) "authorization": basicAuth,
        if (extraHeaders != null) ...extraHeaders,
      },
    );
  }
}

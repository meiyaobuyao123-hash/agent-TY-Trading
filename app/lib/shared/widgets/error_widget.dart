import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Convert any error to a user-friendly Chinese message.
String friendlyErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络后重试';
      case DioExceptionType.connectionError:
        return '无法连接服务器，请检查网络';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 429) return '请求过于频繁，请稍后再试';
        if (code == 404) return '请求的数据不存在';
        if (code != null && code >= 500) return '服务器异常，请稍后再试';
        return '请求失败 ($code)';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '网络异常，请稍后再试';
    }
  }
  if (error is SocketException) {
    return '无法连接服务器，请检查网络';
  }
  if (error is FormatException || error is TypeError) {
    return '数据格式异常，请稍后再试';
  }
  return '加载失败，请稍后再试';
}

/// Error display with retry button.
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  /// Create from a raw error object — always shows friendly Chinese.
  factory AppErrorWidget.fromError({
    Key? key,
    required Object error,
    VoidCallback? onRetry,
  }) {
    return AppErrorWidget(
      key: key,
      message: friendlyErrorMessage(error),
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppTheme.downRed, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

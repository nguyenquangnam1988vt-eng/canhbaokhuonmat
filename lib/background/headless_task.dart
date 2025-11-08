import 'dart:async';
import 'package:flutter/services.dart';
import 'package:background_fetch/background_fetch.dart';

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId;
  bool isTimeout = task.timeout;

  if (isTimeout) {
    print("[BackgroundFetch] Headless task timed-out: $taskId");
    BackgroundFetch.finish(taskId);
    return;
  }

  print('[BackgroundFetch] Headless event received: $taskId');

  // Khởi động detection tạm thời
  // Lưu ý: Trong headless task, không thể sử dụng camera trực tiếp
  // Cần implement logic phù hợp

  BackgroundFetch.finish(taskId);
}

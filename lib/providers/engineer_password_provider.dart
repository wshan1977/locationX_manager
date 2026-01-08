import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 초기 비밀번호: 1234
/// (지금은 앱 실행 중 메모리 값. 필요하면 shared_preferences로 영구 저장 확장 가능)
final engineerPasswordProvider = StateProvider<String>((ref) => '1234');

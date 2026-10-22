import 'dart:convert';

class JwtHelper {
  static Map<String, dynamic> decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw const FormatException('Token không hợp lệ.');
    return jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        )
        as Map<String, dynamic>;
  }
}

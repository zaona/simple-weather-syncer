import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/sponsorship_models.dart';

class SponsorshipService {
  static const String _apiUrl = 'https://afdian.com/api/open/query-sponsor';
  static const List<Sponsor> _fallbackSponsors = [
    Sponsor(name: 'Zaona', totalAmount: 0),
  ];

  /// 返回符合最低支持金额的赞助者列表
  static Future<List<Sponsor>> fetchSponsors({
    double minimumAmount = Sponsor.minimumSupportAmount,
  }) async {
    try {
      final userId = dotenv.env['AFDIAN_USER_ID'] ?? '';
      final token = dotenv.env['AFDIAN_TOKEN'] ?? '';

      if (userId.isEmpty || token.isEmpty) {
        return _fallbackSponsors;
      }

      final body = _buildRequestBody(userId: userId, token: token);
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        return _fallbackSponsors;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final result = data['data'] as Map<String, dynamic>?;

      if (data['ec'] != 200 || result == null) {
        return _fallbackSponsors;
      }

      final list = result['list'] as List<dynamic>? ?? [];
      final sponsors = list
          .map((item) => item is Map<String, dynamic>
              ? Sponsor.fromJson(item)
              : null)
          .whereType<Sponsor>()
          .where((sponsor) => sponsor.totalAmount >= minimumAmount)
          .toList();

      if (sponsors.isEmpty) {
        return _fallbackSponsors;
      }

      return sponsors;
    } catch (_) {
      return _fallbackSponsors;
    }
  }

  static Map<String, dynamic> _buildRequestBody({
    required String userId,
    required String token,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const params = {'page': 1};
    final paramsJson = json.encode(params);

    final signString = '${token}params$paramsJson'
        'ts$ts'
        'user_id$userId';
    final sign = md5.convert(utf8.encode(signString)).toString();

    return {
      'user_id': userId,
      'params': paramsJson,
      'ts': ts,
      'sign': sign,
    };
  }
}


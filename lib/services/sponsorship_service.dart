import 'dart:async';
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

  /// 返回符合最低支持金额的赞助者列表（支持分页查询）
  /// [perPage] 每页数量，范围1-100，默认100
  static Future<List<Sponsor>> fetchSponsors({
    double minimumAmount = Sponsor.minimumSupportAmount,
    int perPage = 100,
  }) async {
    try {
      final userId = dotenv.env['AFDIAN_USER_ID'] ?? '';
      final token = dotenv.env['AFDIAN_TOKEN'] ?? '';

      if (userId.isEmpty || token.isEmpty) {
        throw Exception('获取赞助者数据失败');
      }

      // 限制 perPage 范围在 1-100
      final validPerPage = perPage.clamp(1, 100);

      // 获取第一页以了解总页数
      final firstPageResult = await _fetchSponsorsPage(
        userId: userId,
        token: token,
        page: 1,
        perPage: validPerPage,
      );

      final totalPage = firstPageResult['total_page'] as int? ?? 1;
      final allSponsorsList = <dynamic>[
        ...firstPageResult['list'] as List<dynamic>? ?? [],
      ];

      // 获取剩余页面数据
      if (totalPage > 1) {
        final remainingPages = List.generate(
          totalPage - 1,
          (index) => index + 2,
        );

        for (final page in remainingPages) {
          final pageResult = await _fetchSponsorsPage(
            userId: userId,
            token: token,
            page: page,
            perPage: validPerPage,
          );
          allSponsorsList.addAll(
            pageResult['list'] as List<dynamic>? ?? [],
          );
          // 添加延迟避免请求过快
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // 解析并过滤赞助者
      final sponsors = allSponsorsList
          .whereType<Map<String, dynamic>>()
          .map((item) => Sponsor.fromJson(item))
          .where((sponsor) => sponsor.totalAmount >= minimumAmount)
          .toList();

      return sponsors.isEmpty ? _fallbackSponsors : sponsors;
    } catch (e) {
      // 统一抛出简单错误，不区分具体错误类型
      throw Exception('获取赞助者数据失败');
    }
  }

  /// 获取指定页面的赞助者数据
  static Future<Map<String, dynamic>> _fetchSponsorsPage({
    required String userId,
    required String token,
    required int page,
    required int perPage,
  }) async {
    final body = _buildRequestBody(
      userId: userId,
      token: token,
      page: page,
      perPage: perPage,
    );

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    ).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode != 200) {
      throw Exception('获取赞助者数据失败');
    }

    final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final ec = data['ec'] as int?;
    final result = data['data'] as Map<String, dynamic>?;

    if (ec != 200 || result == null) {
      throw Exception('获取赞助者数据失败');
    }

    return result;
  }

  /// 构建请求体
  static Map<String, dynamic> _buildRequestBody({
    required String userId,
    required String token,
    required int page,
    required int perPage,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final params = {
      'page': page,
      'per_page': perPage,
    };
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


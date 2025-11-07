class Sponsor {
  static const double minimumSupportAmount = 20.0;

  final String name;
  final double totalAmount;

  const Sponsor({
    required this.name,
    required this.totalAmount,
  });

  factory Sponsor.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final name = (user?['name'] as String?)?.trim();
    final amountString = json['all_sum_amount'] as String? ?? '0.00';
    final totalAmount = double.tryParse(amountString) ?? 0.0;

    return Sponsor(
      name: name?.isNotEmpty == true ? name! : '未知赞助者',
      totalAmount: totalAmount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'totalAmount': totalAmount,
    };
  }
}

class SponsorshipResult {
  final List<Sponsor> sponsors;
  final bool fromCache;

  const SponsorshipResult({
    required this.sponsors,
    this.fromCache = false,
  });
}


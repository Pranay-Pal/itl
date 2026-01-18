class Quotation {
  final int id;
  final String quotationNo;
  final String clientName;
  final String clientGstin;
  final String payableAmount;
  final String quotationDate;
  final String? billIssueTo;
  final String? marketingPersonCode;
  final QuotationUser? generatedBy;

  Quotation({
    required this.id,
    required this.quotationNo,
    required this.clientName,
    required this.clientGstin,
    required this.payableAmount,
    required this.quotationDate,
    this.billIssueTo,
    this.marketingPersonCode,
    this.generatedBy,
  });

  factory Quotation.fromJson(Map<String, dynamic> json) {
    return Quotation(
      id: json['id'],
      quotationNo: json['quotation_no'] ?? '',
      clientName: json['client_name'] ?? '',
      clientGstin: json['client_gstin'] ?? '',
      payableAmount: json['payable_amount']?.toString() ?? '0.00',
      quotationDate: json['quotation_date'] ?? '',
      billIssueTo: json['bill_issue_to'],
      marketingPersonCode: json['marketing_person_code'],
      generatedBy: json['generated_by'] != null
          ? QuotationUser.fromJson(json['generated_by'])
          : null,
    );
  }
}

class QuotationUser {
  final int id;
  final String name;
  final String userCode;

  QuotationUser({
    required this.id,
    required this.name,
    required this.userCode,
  });

  factory QuotationUser.fromJson(Map<String, dynamic> json) {
    return QuotationUser(
      id: json['id'],
      name: json['name'] ?? '',
      userCode: json['user_code'] ?? '',
    );
  }
}

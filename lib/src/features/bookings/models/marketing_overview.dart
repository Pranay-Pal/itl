class MarketingOverview {
  final bool status;
  final String message;
  final OverviewData? data;

  MarketingOverview({
    required this.status,
    required this.message,
    this.data,
  });

  factory MarketingOverview.fromJson(Map<String, dynamic> json) {
    return MarketingOverview(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? OverviewData.fromJson(json['data']) : null,
    );
  }
}

class OverviewData {
  final num? totalBookingAmount;
  final num? totalUnpaidInvoiceAmount;
  final num? totalBookings;
  final num? totalBillBookingAmount;
  final num? totalWithoutBillBookings;
  final num? totalPaidInvoiceAmount;
  final num? totalPartialTaxInvoiceAmount;

  // detailed report fields
  final num? billBookings;
  final num? withoutBillBookings;
  final num? allClients;
  final num? generatedInvoices;
  final num? generatedPIs;
  final num? totalInvoiceAmount;
  final num? totalPIAmount;
  final num? paidInvoices;
  final num? partialTaxInvoices;
  final num? settledTaxInvoices;
  final num? totalSettledTaxInvoicesAmount;
  final num? paidPiInvoices;
  final num? totalPaidPIAmount;
  final num? unpaidInvoices;
  final num? canceledGeneratedInvoices;
  final num? totalcanceledGeneratedInvoicesAmount;
  final num? notGeneratedInvoices;
  final num? totalNotGeneratedInvoicesAmount;
  final num? transactions;
  final num? totalTransactionsAmount;
  final num? tdsAmount;
  final num? cashPaidLetters;
  final num? totalCashPaidLettersAmount;
  final num? cashPartialLetters;
  final num? totalcashPartialLettersAmount;
  final num? totalDueAmount;
  final num? cashSettledLetters;
  final num? totalCashSettledLettersAmount;
  final num? totalSettledAmount;
  final num? cashUnpaidLetters;
  final num? totalCashUnpaidAmounts;

  OverviewData({
    this.totalBookingAmount,
    this.totalUnpaidInvoiceAmount,
    this.totalBookings,
    this.totalBillBookingAmount,
    this.totalWithoutBillBookings,
    this.totalPaidInvoiceAmount,
    this.totalPartialTaxInvoiceAmount,
    this.billBookings,
    this.withoutBillBookings,
    this.allClients,
    this.generatedInvoices,
    this.generatedPIs,
    this.totalInvoiceAmount,
    this.totalPIAmount,
    this.paidInvoices,
    this.partialTaxInvoices,
    this.settledTaxInvoices,
    this.totalSettledTaxInvoicesAmount,
    this.paidPiInvoices,
    this.totalPaidPIAmount,
    this.unpaidInvoices,
    this.canceledGeneratedInvoices,
    this.totalcanceledGeneratedInvoicesAmount,
    this.notGeneratedInvoices,
    this.totalNotGeneratedInvoicesAmount,
    this.transactions,
    this.totalTransactionsAmount,
    this.tdsAmount,
    this.cashPaidLetters,
    this.totalCashPaidLettersAmount,
    this.cashPartialLetters,
    this.totalcashPartialLettersAmount,
    this.totalDueAmount,
    this.cashSettledLetters,
    this.totalCashSettledLettersAmount,
    this.totalSettledAmount,
    this.cashUnpaidLetters,
    this.totalCashUnpaidAmounts,
  });

  factory OverviewData.fromJson(Map<String, dynamic> json) {
    return OverviewData(
      totalBookingAmount: json['totalBookingAmount'],
      totalUnpaidInvoiceAmount: json['totalUnpaidInvoiceAmount'],
      totalBookings: json['totalBookings'],
      totalBillBookingAmount: json['totalBillBookingAmount'],
      totalWithoutBillBookings: json['totalWithoutBillBookings'],
      totalPaidInvoiceAmount: json['totalPaidInvoiceAmount'],
      totalPartialTaxInvoiceAmount: json['totalPartialTaxInvoiceAmount'],
      billBookings: json['billBookings'],
      withoutBillBookings: json['withoutBillBookings'],
      allClients: json['allClients'],
      generatedInvoices: json[
          'GeneratedInvoices'], // API key case sensitive? adhering to provided sample
      generatedPIs: json['GeneratedPIs'],
      totalInvoiceAmount: json['totalInvoiceAmount'],
      totalPIAmount: json['totalPIAmount'],
      paidInvoices: json['paidInvoices'],
      partialTaxInvoices: json['partialTaxInvoices'],
      settledTaxInvoices: json['settledTaxInvoices'],
      totalSettledTaxInvoicesAmount: json['totalSettledTaxInvoicesAmount'],
      paidPiInvoices: json['paidPiInvoices'],
      totalPaidPIAmount: json['totalPaidPIAmount'],
      unpaidInvoices: json['unpaidInvoices'],
      canceledGeneratedInvoices: json['canceledGeneratedInvoices'],
      totalcanceledGeneratedInvoicesAmount:
          json['totalcanceledGeneratedInvoicesAmount'],
      notGeneratedInvoices: json['notGeneratedInvoices'],
      totalNotGeneratedInvoicesAmount: json['totalNotGeneratedInvoicesAmount'],
      transactions: json['transactions'],
      totalTransactionsAmount: json['totalTransactionsAmount'],
      tdsAmount: json['tdsAmount'],
      cashPaidLetters: json['cashPaidLetters'],
      totalCashPaidLettersAmount: json['totalCashPaidLettersAmount'],
      cashPartialLetters: json['cashPartialLetters'],
      totalcashPartialLettersAmount: json['totalcashPartialLettersAmount'],
      totalDueAmount: json['totalDueAmount'],
      cashSettledLetters: json['cashSettledLetters'],
      totalCashSettledLettersAmount: json['totalCashSettledLettersAmount'],
      totalSettledAmount: json['totalSettledAmount'],
      cashUnpaidLetters: json['cashUnpaidLetters'],
      totalCashUnpaidAmounts: json['totalCashUnpaidAmounts'],
    );
  }
}

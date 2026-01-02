class MarketingProfileResponse {
  final bool status;
  final String message;
  final MarketingProfileData data;

  MarketingProfileResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory MarketingProfileResponse.fromJson(Map<String, dynamic> json) {
    return MarketingProfileResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: MarketingProfileData.fromJson(json['data'] ?? {}),
    );
  }
}

class MarketingProfileData {
  final MarketingProfile profile;
  final String? avatar;
  final MarketingStats stats;
  final List<RecentTransaction> recentTransactions;

  MarketingProfileData({
    required this.profile,
    this.avatar,
    required this.stats,
    this.recentTransactions = const [],
  });

  factory MarketingProfileData.fromJson(Map<String, dynamic> json) {
    var rawTransactions = json['recent_transactions'];
    List<RecentTransaction> transactions = [];
    if (rawTransactions != null) {
      if (rawTransactions is List) {
        transactions = rawTransactions
            .map((e) => RecentTransaction.fromJson(e))
            .toList();
      }
    }

    return MarketingProfileData(
      profile: MarketingProfile.fromJson(json['profile'] ?? {}),
      avatar: json['avatar'],
      stats: MarketingStats.fromJson(json['stats'] ?? {}),
      recentTransactions: transactions,
    );
  }
}

class MarketingProfile {
  final int id;
  final String? name;
  final String? userCode;
  final String? email;
  final String? phone;

  MarketingProfile({
    required this.id,
    this.name,
    this.userCode,
    this.email,
    this.phone,
  });

  factory MarketingProfile.fromJson(Map<String, dynamic> json) {
    return MarketingProfile(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'],
      userCode: json['user_code'],
      email: json['email'],
      phone: json['phone'],
    );
  }
}

class RecentTransaction {
  final int id;
  final String? invoiceNo;
  final double amountReceived;
  final String? paymentMode;
  final String? transactionDate;

  RecentTransaction({
    required this.id,
    this.invoiceNo,
    required this.amountReceived,
    this.paymentMode,
    this.transactionDate,
  });

  factory RecentTransaction.fromJson(Map<String, dynamic> json) {
    return RecentTransaction(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      invoiceNo: json['invoice_no'],
      amountReceived: double.tryParse(json['amount_received']?.toString() ?? '0') ?? 0.0,
      paymentMode: json['payment_mode'],
      transactionDate: json['transaction_date'],
    );
  }
}

class MarketingStats {
  // Bookings
  final int totalBookings;
  final double totalBookingAmount;
  final int billBookings;
  final double totalBillBookingAmount;
  final int withoutBillBookings;
  final double totalWithoutBillBookings;

  // Invoices
  final int notGeneratedInvoices;
  final double totalNotGeneratedInvoicesAmount;
  final int partialTaxInvoices;
  final double totalPartialTaxInvoiceAmount;
  final int unpaidInvoices;
  final double totalUnpaidInvoiceAmount;
  final int canceledGeneratedInvoices;
  final double totalCanceledGeneratedInvoicesAmount;

  // PI (Proforma Invoices)
  final int generatedPIs;
  final double totalPIAmount;
  final int paidPiInvoices;
  final double totalPaidPIAmount;

  // Transactions
  final int transactions;
  final double totalTransactionsAmount;

  // Cash / Letters
  final int cashPaidLetters;
  final double totalCashPaidLettersAmount;
  final int cashUnpaidLetters; // often null or 0
  final double totalCashUnpaidAmounts;
  final int cashPartialLetters;
  final double totalDueAmount;
  final int cashSettledLetters;
  final double totalSettledAmount;

  // Clients
  final int allClients;
  final double tdsAmount;

  // Personal Expenses
  final double totalPersonalExpensesAmount;
  final double totalApprovedPersonalExpensesAmount;

  MarketingStats({
    this.totalBookings = 0,
    this.totalBookingAmount = 0.0,
    this.billBookings = 0,
    this.totalBillBookingAmount = 0.0,
    this.withoutBillBookings = 0,
    this.totalWithoutBillBookings = 0.0,
    this.notGeneratedInvoices = 0,
    this.totalNotGeneratedInvoicesAmount = 0.0,
    this.partialTaxInvoices = 0,
    this.totalPartialTaxInvoiceAmount = 0.0,
    this.unpaidInvoices = 0,
    this.totalUnpaidInvoiceAmount = 0.0,
    this.canceledGeneratedInvoices = 0,
    this.totalCanceledGeneratedInvoicesAmount = 0.0,
    this.generatedPIs = 0,
    this.totalPIAmount = 0.0,
    this.paidPiInvoices = 0,
    this.totalPaidPIAmount = 0.0,
    this.transactions = 0,
    this.totalTransactionsAmount = 0.0,
    this.cashPaidLetters = 0,
    this.totalCashPaidLettersAmount = 0.0,
    this.cashUnpaidLetters = 0,
    this.totalCashUnpaidAmounts = 0.0,
    this.cashPartialLetters = 0,
    this.totalDueAmount = 0.0,
    this.cashSettledLetters = 0,
    this.totalSettledAmount = 0.0,
    this.allClients = 0,
    this.tdsAmount = 0.0,
    this.totalPersonalExpensesAmount = 0.0,
    this.totalApprovedPersonalExpensesAmount = 0.0,
  });

  factory MarketingStats.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      return int.tryParse(val.toString()) ?? 0;
    }

    return MarketingStats(
      totalBookings: parseInt(json['totalBookings']),
      totalBookingAmount: parseDouble(json['totalBookingAmount']),
      billBookings: parseInt(json['billBookings']),
      totalBillBookingAmount: parseDouble(json['totalBillBookingAmount']),
      withoutBillBookings: parseInt(json['withoutBillBookings']),
      totalWithoutBillBookings: parseDouble(json['totalWithoutBillBookings']),
      
      notGeneratedInvoices: parseInt(json['notGeneratedInvoices']),
      totalNotGeneratedInvoicesAmount: parseDouble(json['totalNotGeneratedInvoicesAmount']),
      partialTaxInvoices: parseInt(json['partialTaxInvoices']),
      totalPartialTaxInvoiceAmount: parseDouble(json['totalPartialTaxInvoiceAmount']),
      unpaidInvoices: parseInt(json['unpaidInvoices']),
      totalUnpaidInvoiceAmount: parseDouble(json['totalUnpaidInvoiceAmount']),
      canceledGeneratedInvoices: parseInt(json['canceledGeneratedInvoices']),
      totalCanceledGeneratedInvoicesAmount: parseDouble(json['totalcanceledGeneratedInvoicesAmount']),
      
      generatedPIs: parseInt(json['GeneratedPIs']),
      totalPIAmount: parseDouble(json['totalPIAmount']),
      paidPiInvoices: parseInt(json['paidPiInvoices']),
      totalPaidPIAmount: parseDouble(json['totalPaidPIAmount']),
      
      transactions: parseInt(json['transactions']),
      totalTransactionsAmount: parseDouble(json['totalTransactionsAmount']),
      
      cashPaidLetters: parseInt(json['cashPaidLetters']),
      totalCashPaidLettersAmount: parseDouble(json['totalCashPaidLettersAmount']),
      cashUnpaidLetters: parseInt(json['cashUnpaidLetters']),
      totalCashUnpaidAmounts: parseDouble(json['totalCashUnpaidAmounts']),
      cashPartialLetters: parseInt(json['cashPartialLetters']),
      totalDueAmount: parseDouble(json['totalDueAmount']),
      cashSettledLetters: parseInt(json['cashSettledLetters']),
      totalSettledAmount: parseDouble(json['totalSettledAmount']),
      
      allClients: parseInt(json['allClients']),
      tdsAmount: parseDouble(json['tdsAmount']),
      
      totalPersonalExpensesAmount: parseDouble(json['totalPersonalExpensesAmount']),
      totalApprovedPersonalExpensesAmount: parseDouble(json['totalApprovedPersonalExpensesAmount']),
    );
  }
}

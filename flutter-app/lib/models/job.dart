class Job {
  final String jobId;
  final String customerId;
  final String? customerName;
  final String? blNumber;
  final String? cusdecNumber;
  final String? cusdecDate;
  final String? openDate;
  final String? shipmentCategory;
  final String? chassisNumber;
  final String? exporter;
  final String? transporter;
  final String? lcNumber;
  final String? containerNumber;
  final String? transportDeliveryDate;
  final String status;
  final String? assignedTo;
  final List<JobAssignedUser> assignedUsers;
  final String? createdDate;
  final String? completedDate;
  final double advancePayment;
  final double? billTotalAmount;
  final double billPaidAmount;
  final String? pettyCashStatus;

  const Job({
    required this.jobId,
    required this.customerId,
    this.customerName,
    this.blNumber,
    this.cusdecNumber,
    this.cusdecDate,
    this.openDate,
    this.shipmentCategory,
    this.chassisNumber,
    this.exporter,
    this.transporter,
    this.lcNumber,
    this.containerNumber,
    this.transportDeliveryDate,
    this.status = 'Open',
    this.assignedTo,
    this.assignedUsers = const [],
    this.createdDate,
    this.completedDate,
    this.advancePayment = 0,
    this.billTotalAmount,
    this.billPaidAmount = 0,
    this.pettyCashStatus,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    List<JobAssignedUser> users = [];
    if (json['assignedUsers'] != null) {
      users = (json['assignedUsers'] as List<dynamic>).map((e) {
        if (e is Map<String, dynamic>) {
          return JobAssignedUser(
            userId: e['userId']?.toString() ?? '',
            userName: e['userName']?.toString() ?? '',
          );
        }
        return JobAssignedUser(userId: e.toString(), userName: '');
      }).toList();
    }
    return Job(
      jobId: json['jobId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName'],
      blNumber: json['blNumber'],
      cusdecNumber: json['cusdecNumber'],
      cusdecDate: json['cusdecDate'],
      openDate: json['openDate'],
      shipmentCategory: json['shipmentCategory'],
      chassisNumber: json['chassisNumber'],
      exporter: json['exporter'],
      transporter: json['transporter'],
      lcNumber: json['lcNumber'],
      containerNumber: json['containerNumber'],
      transportDeliveryDate: json['transportDeliveryDate'],
      status: json['status'] ?? 'Open',
      assignedTo: json['assignedTo'],
      assignedUsers: users,
      createdDate: json['createdDate'],
      completedDate: json['completedDate'],
      advancePayment: _dbl(json['advancePayment']),
      billTotalAmount: json['billTotalAmount'] != null
          ? _dbl(json['billTotalAmount'])
          : null,
      billPaidAmount: _dbl(json['billPaidAmount']),
      pettyCashStatus: json['pettyCashStatus'],
    );
  }

  static double _dbl(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  String get statusLabel => status;
}

class JobAssignedUser {
  final String userId;
  final String userName;

  const JobAssignedUser({required this.userId, required this.userName});
}

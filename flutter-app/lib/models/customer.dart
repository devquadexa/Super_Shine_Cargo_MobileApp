class Customer {
  final String customerId;
  final String name;
  final String? mainPhone;
  final String? email;
  final String? website;
  // Residential address
  final String? addressNumber;
  final String? addressStreet1;
  final String? addressStreet2;
  final String? addressCity;
  final String? addressDistrict;
  final String? addressCountry;
  // Office address
  final bool isOfficeAddressSame;
  final String? officeAddressNumber;
  final String? officeAddressStreet1;
  final String? officeAddressStreet2;
  final String? officeAddressCity;
  final String? officeAddressDistrict;
  final String? officeAddressCountry;
  final bool isActive;
  final String? registrationDate;
  final int? creditPeriodDays;
  final List<String> categories;
  final List<ContactPerson> contactPersons;

  const Customer({
    required this.customerId,
    required this.name,
    this.mainPhone,
    this.email,
    this.website,
    this.addressNumber,
    this.addressStreet1,
    this.addressStreet2,
    this.addressCity,
    this.addressDistrict,
    this.addressCountry,
    this.isOfficeAddressSame = false,
    this.officeAddressNumber,
    this.officeAddressStreet1,
    this.officeAddressStreet2,
    this.officeAddressCity,
    this.officeAddressDistrict,
    this.officeAddressCountry,
    required this.isActive,
    this.registrationDate,
    this.creditPeriodDays,
    this.categories = const [],
    this.contactPersons = const [],
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    List<String> cats = [];
    if (json['categories'] != null) {
      final raw = json['categories'] as List<dynamic>;
      cats = raw.map((e) {
        if (e is String) return e;
        if (e is Map) {
          // API returns { categoryId, categoryName }
          return (e['categoryName'] ?? e['name'] ?? '').toString();
        }
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }

    List<ContactPerson> contacts = [];
    if (json['contactPersons'] != null) {
      final raw = json['contactPersons'] as List<dynamic>;
      contacts = raw
          .map((e) => ContactPerson.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Customer(
      customerId: json['customerId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      mainPhone: json['mainPhone'],
      email: json['email'],
      website: json['website'],
      addressNumber: json['addressNumber'],
      addressStreet1: json['addressStreet1'],
      addressStreet2: json['addressStreet2'],
      addressCity: json['addressCity'],
      addressDistrict: json['addressDistrict'],
      addressCountry: json['addressCountry'],
      isOfficeAddressSame: _parseBool(json['isOfficeAddressSame'], fallback: false),
      officeAddressNumber: json['officeAddressNumber'],
      officeAddressStreet1: json['officeAddressStreet1'],
      officeAddressStreet2: json['officeAddressStreet2'],
      officeAddressCity: json['officeAddressCity'],
      officeAddressDistrict: json['officeAddressDistrict'],
      officeAddressCountry: json['officeAddressCountry'],
      isActive: _parseBool(json['isActive'], fallback: true),
      registrationDate: json['registrationDate'],
      creditPeriodDays: json['creditPeriodDays'] is int
          ? json['creditPeriodDays']
          : int.tryParse(json['creditPeriodDays']?.toString() ?? ''),
      categories: cats,
      contactPersons: contacts,
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class ContactPerson {
  final String name;
  final String? phone;
  final String? email;
  final String? designation;

  const ContactPerson({
    required this.name,
    this.phone,
    this.email,
    this.designation,
  });

  factory ContactPerson.fromJson(Map<String, dynamic> json) {
    return ContactPerson(
      name: json['name'] ?? '',
      phone: json['phone'],
      email: json['email'],
      designation: json['designation'],
    );
  }
}

/// SQL Server returns bit columns as 1/0 integers, not Dart bools.
/// This helper handles bool, int (1/0), and null safely.
bool _parseBool(dynamic value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return fallback;
}

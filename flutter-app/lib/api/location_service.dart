import 'package:dio/dio.dart';
import 'client.dart';

class District {
  final int districtId;
  final String districtName;
  final String? province;

  const District({
    required this.districtId,
    required this.districtName,
    this.province,
  });

  factory District.fromJson(Map<String, dynamic> json) => District(
        districtId: json['districtId'] as int,
        districtName: json['districtName'] as String,
        province: json['province'] as String?,
      );

  @override
  String toString() => districtName;
}

class City {
  final int cityId;
  final String cityName;

  const City({required this.cityId, required this.cityName});

  factory City.fromJson(Map<String, dynamic> json) => City(
        cityId: json['cityId'] as int,
        cityName: json['cityName'] as String,
      );

  @override
  String toString() => cityName;
}

class LocationService {
  /// GET /api/locations/districts
  Future<List<District>> getDistricts() async {
    try {
      final response = await apiClient.get('/locations/districts');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => District.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to load districts.');
    }
  }

  /// GET /api/locations/cities/:districtId
  Future<List<City>> getCitiesByDistrict(int districtId) async {
    try {
      final response = await apiClient.get('/locations/cities/$districtId');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => City.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Failed to load cities.');
    }
  }
}

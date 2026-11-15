import 'package:flutter/material.dart';
import '../../../photographer/data/datasources/photo_analytics_remote_data_source.dart';
import '../../../photographer/presentation/screens/photo_analytics_screen.dart';
import '../../../staff/presentation/screens/staff_screen.dart';
import '../../domain/entities/user_entity.dart';

Widget signedInScreen(UserEntity user) {
  if (user.role.trim().toLowerCase() == 'photographer') {
    return PhotoAnalyticsScreen(
      user: user,
      remote: PhotoAnalyticsRemoteDataSource(token: user.token),
    );
  }
  return StaffScreen(user: user);
}

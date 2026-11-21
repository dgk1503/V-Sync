import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:vit_ap_student_app/core/error/exceptions.dart';
import 'package:vit_ap_student_app/core/error/failure.dart';
import 'package:vit_ap_student_app/core/models/credentials.dart';
import 'package:vit_ap_student_app/core/services/vtop_service.dart';
import 'package:vit_ap_student_app/features/attendance/model/capstone_attendance.dart';
import 'package:vit_ap_student_app/init_dependencies.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/vtop_errors.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop_get_client.dart' as vtop;

final capstoneRepositoryProvider = Provider<CapstoneRepository>(
  (ref) => CapstoneRepository(serviceLocator<VtopClientService>()),
);

/// A fetched capstone: the attendance, or none when the student has no
/// registration, plus the raw reply so it can be cached untouched.
class CapstoneFetch {
  const CapstoneFetch({required this.capstone, required this.raw});

  final CapstoneAttendance? capstone;
  final String raw;
}

class CapstoneRepository {
  CapstoneRepository(this.vtopService);

  final VtopClientService vtopService;

  Future<Either<Failure, CapstoneFetch>> fetch(Credentials credentials) async {
    try {
      final body = await vtopService.executeWithRetry(
        credentials: credentials,
        operation: (client) => vtop.fetchAttendanceWithCapstone(
          client: client,
          semesterId: credentials.semSubId,
        ),
      );
      return Right(
        CapstoneFetch(
          capstone: CapstoneAttendance.fromResponse(body),
          raw: body,
        ),
      );
    } on SocketException {
      return Left(Failure('No internet connection'));
    } on VtopError catch (rustError) {
      final message = await VtopException.getFailureMessage(rustError);
      return Left(Failure(message));
    } on FormatException catch (e) {
      debugPrint('Capstone JSON parsing failed: $e');
      return Left(Failure('Invalid response format from server'));
    } catch (e) {
      debugPrint('Error fetching capstone attendance: $e');
      return Left(Failure('Failed to fetch capstone attendance: $e'));
    }
  }
}

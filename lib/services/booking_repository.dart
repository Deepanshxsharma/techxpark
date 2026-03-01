import 'booking_service.dart';

/// Thin facade that delegates to [BookingService].
///
/// Kept for backward compatibility — existing screens that import
/// BookingRepository will continue to work unchanged.
class BookingRepository {
  BookingRepository._();
  static final instance = BookingRepository._();

  final _service = BookingService.instance;

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  EXTEND BOOKING                                                        */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Future<DateTime> extendBooking({
    required String bookingId,
    required int extraMinutes,
  }) =>
      _service.extendBooking(
        bookingId: bookingId,
        extraMinutes: extraMinutes,
      );

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  CANCEL BOOKING                                                        */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Future<String> cancelBooking({required String bookingId}) =>
      _service.cancelBooking(bookingId: bookingId);

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  COMPLETE BOOKING                                                      */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Future<void> completeBooking({required String bookingId}) =>
      _service.completeBooking(bookingId: bookingId);

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  HELPERS                                                                */
  /* ═══════════════════════════════════════════════════════════════════════ */
  bool canCancel(DateTime startTime) => _service.canCancel(startTime);

  int minutesUntilCutoff(DateTime startTime) =>
      _service.minutesUntilCutoff(startTime);
}

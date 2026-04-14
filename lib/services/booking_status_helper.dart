/// Helper utilities for booking status validation and normalization.
/// Used across BookingService, BookingHelper, and UI layers.
class BookingStatusHelper {
  BookingStatusHelper._();

  /// Statuses that count as "active" and block new bookings.
  static const List<String> blockingStatuses = [
    'upcoming',
    'active',
    'booked',
    'parked',
    'requested',
  ];

  /// Safely converts any status value to a lowercase, trimmed string.
  static String normalize(Object? raw) {
    if (raw == null) return '';
    return raw.toString().trim().toLowerCase();
  }

  /// Whether the status represents an upcoming (not-yet-started) booking.
  static bool isUpcoming(String status) {
    final normalized = normalize(status);
    return normalized == 'upcoming';
  }

  /// Whether the status represents a currently live parking session.
  static bool isLive(String status) {
    final normalized = normalize(status);
    return normalized == 'active' ||
        normalized == 'booked' ||
        normalized == 'parked' ||
        normalized == 'requested';
  }
}

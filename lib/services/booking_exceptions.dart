/// Custom exceptions for the booking fraud & abuse protection layer.
/// These provide typed error handling with user-friendly messages.

// ─── BASE ──────────────────────────────────────────────────────────────────────

abstract class BookingException implements Exception {
  final String message;
  final String userMessage;
  const BookingException(this.message, this.userMessage);

  /// Generic booking exception for internal use.
  const factory BookingException.generic(String message, String userMessage) =
      _GenericBookingException;

  @override
  String toString() => 'BookingException: $message';
}

class _GenericBookingException extends BookingException {
  const _GenericBookingException(super.message, super.userMessage);
}

// ─── SLOT CONFLICT ─────────────────────────────────────────────────────────────

class SlotAlreadyBookedException extends BookingException {
  final DateTime conflictStart;
  final DateTime conflictEnd;

  SlotAlreadyBookedException({
    required this.conflictStart,
    required this.conflictEnd,
  }) : super(
          'Slot already booked from $conflictStart to $conflictEnd',
          'This slot is already booked during your selected time. Please choose a different slot or time.',
        );
}

// ─── USER OVERLAP ──────────────────────────────────────────────────────────────

class UserBookingOverlapException extends BookingException {
  final String existingBookingId;

  UserBookingOverlapException({required this.existingBookingId})
      : super(
          'User already has an overlapping booking: $existingBookingId',
          'You already have a booking during this time. Please choose a different time.',
        );
}

// ─── QUOTA EXCEEDED ────────────────────────────────────────────────────────────

class UserBookingLimitExceededException extends BookingException {
  final int current;
  final int max;

  UserBookingLimitExceededException({required this.current, required this.max})
      : super(
          'User has $current active bookings (max $max)',
          'You have reached the maximum of $max active bookings. Please complete or cancel an existing booking first.',
        );
}

// ─── CANCELLATION ──────────────────────────────────────────────────────────────

class CancellationNotAllowedException extends BookingException {
  final int minutesRemaining;

  CancellationNotAllowedException({required this.minutesRemaining})
      : super(
          'Cancellation blocked: only $minutesRemaining min before start',
          'Cancellation is not allowed within 15 minutes of the booking start time.',
        );
}

// ─── STATUS TRANSITION ────────────────────────────────────────────────────────

class InvalidStatusTransitionException extends BookingException {
  final String from;
  final String to;

  InvalidStatusTransitionException({required this.from, required this.to})
      : super(
          'Invalid status transition: $from → $to',
          'This booking cannot be updated to "$to" status.',
        );
}

// ─── AUTH / NOT FOUND ──────────────────────────────────────────────────────────

class BookingNotFoundException extends BookingException {
  const BookingNotFoundException()
      : super('Booking not found', 'This booking could not be found.');
}

class UnauthorizedException extends BookingException {
  const UnauthorizedException()
      : super(
          'User does not own this booking',
          'You are not authorized to modify this booking.',
        );
}

class NotAuthenticatedException extends BookingException {
  const NotAuthenticatedException()
      : super(
          'User not authenticated',
          'Please sign in to continue.',
        );
}

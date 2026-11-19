import 'package:flutter/widgets.dart';

/// A StreamBuilder may retain the previous stream's data after switching
/// subscriptions. Until the new stream emits, that cached value does not
/// prove availability for the currently selected stadium/date.
abstract final class BookingStreamFreshness {
  static bool isAwaitingCurrentStream<T>(AsyncSnapshot<T> snapshot) {
    return snapshot.connectionState == ConnectionState.none ||
        snapshot.connectionState == ConnectionState.waiting;
  }
}

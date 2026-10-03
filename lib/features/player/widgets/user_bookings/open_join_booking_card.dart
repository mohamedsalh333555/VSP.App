import 'package:flutter/material.dart';

import '../../../../data/models.dart';
import '../../../../shared/widgets/public_match_card.dart';

/// Open-Join booking card in My Bookings.
///
/// The visual presentation is intentionally the same canonical card used by
/// the Home feed. Keeping one visual component prevents the same match from
/// changing shape when it moves from discovery to My Bookings.
class OpenJoinBookingCard extends StatelessWidget {
  final Booking booking;
  final bool isHistory;

  const OpenJoinBookingCard({
    super.key,
    required this.booking,
    required this.isHistory,
  });

  @override
  Widget build(BuildContext context) {
    return PublicMatchCard(
      booking: booking,
      highlighted: !isHistory,
    );
  }
}

/// Delivery workflow:
/// Assigned -> Accepted -> Picked Up -> Out for Delivery -> (OTP) -> Delivered
class OrderStatus {
  static const pending = 'pending';
  static const assigned = 'assigned';
  static const accepted = 'accepted';
  static const pickedUp = 'picked_up';
  static const outForDelivery = 'out_for_delivery';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  static const active = <String>[assigned, accepted, pickedUp, outForDelivery];

  static const allowedTransitions = <String, Set<String>>{
    assigned: {accepted},
    accepted: {pickedUp},
    pickedUp: {outForDelivery},
    outForDelivery: {delivered},
    delivered: {},
    cancelled: {},
  };

  static bool canMove(String from, String to) =>
      allowedTransitions[from]?.contains(to) ?? false;

  /// The next step the driver can take by pressing a button.
  /// Delivered is not here: it needs the OTP.
  static String? nextManual(String status) {
    switch (status) {
      case assigned:
        return accepted;
      case accepted:
        return pickedUp;
      case pickedUp:
        return outForDelivery;
      default:
        return null;
    }
  }

  static String actionLabel(String status) {
    switch (status) {
      case assigned:
        return 'Accept delivery';
      case accepted:
        return 'Parcel picked up';
      case pickedUp:
        return 'Start delivery';
      default:
        return '';
    }
  }

  static String label(String status) {
    switch (status) {
      case pending:
        return 'New';
      case assigned:
        return 'Assigned';
      case accepted:
        return 'Accepted';
      case pickedUp:
        return 'Picked up';
      case outForDelivery:
        return 'Out for delivery';
      case delivered:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// 0..4 progress step for the progress bar.
  static int step(String status) {
    switch (status) {
      case assigned:
        return 1;
      case accepted:
        return 2;
      case pickedUp:
        return 3;
      case outForDelivery:
        return 4;
      case delivered:
        return 5;
      default:
        return 0;
    }
  }
}

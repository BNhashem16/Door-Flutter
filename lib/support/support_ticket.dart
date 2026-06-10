/// Support / report-an-issue domain types.
///
/// Stored under `/support_tickets/{ownerUid}/{ticketId}` in the Realtime
/// Database. Hand-written `fromMap`/`toMap` (no code-gen, per project
/// conventions). `name`/`email` are denormalized so the admin inbox stays
/// readable even after the reporter edits or deletes their profile.
library;

/// What the report is about.
enum TicketCategory { bug, suggestion, other }

/// Lifecycle: a resident opens a ticket, an admin resolves it.
enum TicketStatus { open, resolved }

/// Immutable user-submitted support report.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.uid,
    required this.name,
    required this.email,
    required this.category,
    required this.message,
    required this.createdAt,
    required this.status,
  });

  /// RTDB push key.
  final String id;

  /// Reporter uid (also the parent key under `/support_tickets`).
  final String uid;

  /// Denormalized reporter display name at submit time.
  final String name;

  /// Denormalized reporter email at submit time.
  final String email;

  final TicketCategory category;
  final String message;

  /// Epoch milliseconds (server-stamped).
  final int createdAt;

  final TicketStatus status;

  bool get isOpen => status == TicketStatus.open;

  factory SupportTicket.fromMap(
    String id,
    String uid,
    Map<dynamic, dynamic> map,
  ) {
    return SupportTicket(
      id: id,
      uid: uid,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      category: switch (map['category']) {
        'bug' => TicketCategory.bug,
        'suggestion' => TicketCategory.suggestion,
        _ => TicketCategory.other,
      },
      message: (map['message'] ?? '') as String,
      createdAt: (map['createdAt'] ?? 0) as int,
      status: map['status'] == 'resolved'
          ? TicketStatus.resolved
          : TicketStatus.open,
    );
  }

  Map<String, Object?> toMap() => {
        'name': name,
        'email': email,
        'category': switch (category) {
          TicketCategory.bug => 'bug',
          TicketCategory.suggestion => 'suggestion',
          TicketCategory.other => 'other',
        },
        'message': message,
        'createdAt': createdAt,
        'status': status == TicketStatus.resolved ? 'resolved' : 'open',
      };
}

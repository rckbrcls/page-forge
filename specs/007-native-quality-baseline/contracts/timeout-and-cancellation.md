# Contract: Timeout and Cancellation

## Purpose

Define deterministic ownership for adapter operations that race useful work
against a deadline or caller cancellation.

## SMTP reply queue

1. Each call waiting for a reply owns one unique waiter token.
2. A waiter is resumed exactly once by a reply, queue finish, timeout
   cancellation, or caller cancellation.
3. Timeout and cancellation remove the waiter before returning a terminal
   outcome.
4. A late reply after removal is retained or routed according to the queue's
   normal reply policy; it never resumes the removed continuation.
5. Finishing the queue drains every pending waiter exactly once.
6. Cancellation before suspension returns immediately without registering an
   orphan waiter.

## Deadline behavior

1. A configured deadline starts when the bounded operation begins.
2. When the deadline expires, pending work receives cooperative cancellation.
3. The public operation reaches a typed terminal outcome within one second after
   the deadline.
4. Tests use controlled continuations or local embedded channels, never a live
   SMTP provider.

## Delivery classification

1. Before SMTP message data begins, timeout/cancellation uses the existing
   retryable or terminal typed failure mapping.
2. After message data begins, loss of a definitive server reply remains
   `delivery_unknown`.
3. Raw SwiftNIO, TLS, socket, continuation, or task-group errors do not reach the
   presentation model.

## Archive and XML review

Bounded archive and XML operations must satisfy the same release contract. They
may keep adapter-specific timeout types, but a losing timeout-race child must not
retain a resource, continuation, or stream that prevents the parent scope from
returning.

## Required evidence

- Cancellation before waiter registration.
- Cancellation after waiter registration.
- Reply wins timeout race.
- Timeout wins reply race.
- Queue finish with multiple waiters.
- Late reply after cancellation.
- Exactly-once resumption under repeated finish/cancel signals.
- Elapsed release bound at or below one second after deadline/cancellation.

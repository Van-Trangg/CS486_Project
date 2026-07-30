## Business requirement description

After the Phase 1 design was completed, the School of Computer Science piloted the space booking system for one semester. Based on the pilot, the Facility Manager announces one change to the maintenance rules and a set of new operating conditions that the system must support. Phase 2 extends the Phase 1 system accordingly.

### Requirement change: maintenance impact levels

In Phase 1, any space under maintenance could not be booked. The Facility Manager now refines this rule:

- Some maintenance work makes a space unusable, such as electrical repair, floor replacement, or air-conditioning replacement in summer. Such maintenance has impact level **out-of-service**. The space cannot be booked for any time period that overlaps the maintenance period, exactly as in Phase 1.
- Other maintenance work affects only part of the space's equipment or comfort while the space itself remains usable, such as a broken projector, one faulty air conditioner out of several, or a damaged whiteboard. Such maintenance has impact level **advisory**. The space can still be booked, but the system must notify the requester of all active advisories on the space at booking time and must record that the requester was informed through an acknowledgement stored with the booking.

Additional rules:

- A space may have several active maintenance records at the same time, with different impact levels.
- The impact level of a maintenance record may be escalated from advisory to out-of-service or downgraded while the maintenance is still open.
- If an advisory maintenance record is escalated to out-of-service, already-approved bookings that overlap the maintenance period must be identified so that staff can contact the requesters. The system must support finding these affected bookings.

### New operating conditions: concurrent booking and approval

At the beginning of each semester, many users may submit booking requests at approximately the same time. Popular spaces may therefore receive several requests for overlapping time periods within a short interval.

For selected space types, requests that satisfy the usage policy may be approved automatically at submission time. Other requests continue through the existing staff approval workflow.

Because users and staff may perform booking operations concurrently, multiple operations may check the availability of the same space before any of them records its result. Without appropriate concurrency control, conflicting bookings may be approved.

The system must ensure that two approved bookings cannot use the same space during overlapping time periods, regardless of whether the bookings are created through instant booking or staff approval. This rule must remain valid even when multiple users or staff members perform booking and approval operations simultaneously.

### New reporting needs

With the accumulated booking and maintenance history, the Facility Manager needs the system to support the following reports:

- Total approved booking hours of each space for a given semester.
- Number of approved bookings by weekday and hour for a given semester.
- Available spaces that satisfy a required capacity and a required facility list within a given time period.
- Approved bookings affected when a maintenance record is escalated to out-of-service.

Students must implement all of these queries. They must then identify suitable indexes for the booking conflict check, the room finder query, and one additional reporting query selected from the list above.

The queries should be tested on a sufficiently large generated dataset so that differences before and after indexing can be observed.

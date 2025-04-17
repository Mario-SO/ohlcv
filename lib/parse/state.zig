const std = @import("std");

/// Parser possible states.
pub const State = enum {
    start_field,
    in_int,
    in_frac,
    after_field,
    end_of_line,
};

/// Tiny state‑machine helper. No heap, no I/O here.
pub const Machine = struct {
    state: State = .start_field,
    prev: State = .start_field,

    pub fn reset(self: *Machine) void {
        self.* = .{ .state = .start_field, .prev = .start_field };
    }

    /// Transition and return the new state.
    pub fn advance(self: *Machine, next: State) State {
        self.prev = self.state;
        self.state = next;
        return next;
    }

    /// Convenience check: `if (m.is(.in_int)) …`
    pub fn is(self: Machine, wanted: State) bool {
        return self.state == wanted;
    }
};

test "Machine transitions start → in_int → after_field" {
    var m = Machine{}; // default state = .start_field
    try std.testing.expect(m.is(.start_field));

    _ = m.advance(.in_int);
    try std.testing.expect(m.is(.in_int));

    _ = m.advance(.after_field);
    try std.testing.expect(m.is(.after_field));
}

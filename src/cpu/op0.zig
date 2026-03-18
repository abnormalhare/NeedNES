// addressing mode functions

const CPU = @import("cpu.zig").CPU;

pub fn timing_check(self: *CPU, time: u3) void {
    if (self.timing >= time) self.timing = 0;
}

// implied: 2
pub fn imp(self: *CPU) void {
    timing_check(self, 2);

    switch (self.timing) {
        else => {},
        0 => self.read(),
    }
}

// immediate: 2
pub fn imm(self: *CPU) void {
    timing_check(self, 2);

    switch (self.timing) {
        else => {},
        0 => self.read_pc(),
    }
}

// absolute - read: 4
pub fn a_r(self: *CPU) void {
    timing_check(self, 4);

    switch (self.timing) {
        else => {},
        2, 3 => self.read_pc(),
        0 => self.read(),
    }
}

// absolute - rmw: 6
pub fn a_rmw(self: *CPU) void {
    timing_check(self, 6);

    switch (self.timing) {
        else => {},
        2, 3 => self.read_pc(),
        4 => self.read(),
        5, 0 => self.write(),
    }
}

// absolute - w: 4
pub fn a_w(self: *CPU) void {
    timing_check(self, 4);

    switch (self.timing) {
        else => {},
        2, 3 => self.read_pc(),
        0 => self.write(),
    }
}

// zero page - r: 3
pub fn z_r(self: *CPU) void {
    timing_check(self, 3);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        0 => self.read(),
    }
}

// zero page - rmw: 5
pub fn z_rmw(self: *CPU) void {
    timing_check(self, 5);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3 => self.read(),
        4, 0 => self.write(),
    }
}

// zero page - w: 3
pub fn z_w(self: *CPU) void {
    timing_check(self, 3);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        0 => self.write(),
    }
}

// zero page indexed - r: 4
pub fn zi_r(self: *CPU) void {
    timing_check(self, 4);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3, 0 => self.read(),
    }
}

// zero page indexed - rmw: 6
pub fn zi_rmw(self: *CPU) void {
    timing_check(self, 6);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3, 4 => self.read(),
        5, 0 => self.write(),
    }
}

// zero page indexed - w: 4
pub fn zi_w(self: *CPU) void {
    timing_check(self, 4);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3 => self.read(),
        4 => self.write(),
    }
}

// absolute indexed - r: 4/5
pub fn ai_r(self: *CPU) void {
    timing_check(self, 5);

    switch (self.timing) {
        else => {},
        2, 3 => self.read_pc(),
        4, 0 => self.read(),
    }
}

// absolute indexed - rmw: 7
pub fn ai_rmw(self: *CPU) void {
    timing_check(self, 7);

    switch (self.timing) {
        else => {},
        2, 3 => self.read_pc(),
        4, 5 => self.read(),
        6, 0 => self.write(),
    }
}

// absolute indexed - w: 5
pub fn ai_w(self: *CPU) void {
    timing_check(self, 5);

    switch (self.timing) {
        else => {},
        2, 3 => self.read_pc(),
        4 => self.read(),
        0 => self.write(),
    }
}

// branch: 2/3/4
pub fn b(self: *CPU) void {
    timing_check(self, 4);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3, 0 => self.read(),
    }
}

// indexed indirect - r: 6
pub fn xi_r(self: *CPU) void {
    timing_check(self, 6);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3, 4, 5, 0 => self.read(),
    }
}

// indexed indirect - rmw: 8
pub fn xi_rmw(self: *CPU) void {
    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3, 4, 5, 6 => self.read(),
        7, 0 => self.write(),
    }
}

// indexed indirect - w: 6
pub fn xi_w(self: *CPU) void {
    timing_check(self, 6);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3, 4, 5 => self.read(),
        0 => self.write(),
    }
}

// indirect indexed - r: 5/6
pub fn ix_r(self: *CPU) void {
    timing_check(self, 6);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3, 4, 5, 0 => self.read(),
    }
}

// indirect indexed - rmw: 8
pub fn ix_rmw(self: *CPU) void {
    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3, 4, 5, 6 => self.read(),
        7, 0 => self.write(),
    }
}

// indirect indexed - w: 6
pub fn ix_w(self: *CPU) void {
    timing_check(self, 6);

    switch (self.timing) {
        else => {},
        2 => self.read_pc(),
        3, 4, 5 => self.read(),
        0 => self.write(),
    }
}

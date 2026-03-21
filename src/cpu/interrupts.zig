const CPU = @import("cpu.zig").CPU;
const op0 = @import("op0.zig");

fn op0_rst(self: *CPU) void {
    op0.timing_check(self, 7);

    switch (self.timing) {
        else => {},
        0, 1, 2 => self.read(),
        3, 4, 5 => self.read_stack(),
        6 => self.read(),
    }
}

fn op0_brk(self: *CPU) void {
    op0.timing_check(self, 7);

    switch (self.timing) {
        else => {},
        2 => self.read(),
        3, 4, 5 => self.write_stack(),
        6, 0 => self.read(),
    }
}

const InterruptType = enum { brk, rst, irq, nmi };

var int_type: ?InterruptType = null;
var curr_int_type: ?InterruptType = null;

pub fn set_interrupt(int: InterruptType) void {
    int_type = int;
}

pub fn get_interrupt() ?InterruptType {
    return int_type;
}

pub fn interrupt(self: *CPU) void {
    if (curr_int_type) |int| {
        switch (int) {
            .rst => int_rst(self),
            .brk => int_brk(self),
            .irq => int_irq(self),
            .nmi => int_nmi(self),
        }
    }
    if (int_type) |int| {
        curr_int_type = int;
        int_type = null;
    }
}

fn interrupt_handler(self: *CPU, addr: u16) void {
    switch (self.timing) {
        else => {},
        2 => {
            self.addr = 0x100 + @as(u16, self.s);
            self.data = @truncate(self.pc >> 8);
        },
        3 => {
            self.addr = 0x100 + @as(u16, self.s);
            self.data = @truncate(self.pc);
        },
        4 => {
            self.addr = 0x100 + @as(u16, self.s);
            self.data = self.p.to_num();
        },
        5 => self.addr = addr,
        6 => {
            self.adl = self.data;
            self.addr += 1;
        },
        0 => {
            self.pc = self.adl;
            self.pc += @as(u16, self.data) << 8;
        },
    }
}

fn int_brk(self: *CPU) void {
    if (self.phi == 0) {
        op0_brk(self);
        return;
    }

    if (self.timing == 4) {
        self.p.i = 1;
        self.p.b = 1;
    }

    interrupt_handler(self, 0xFFFE);

    if (self.timing == 4) {
        self.p.b = 0;
    }
}

fn int_rst(self: *CPU) void {
    if (self.phi == 0) {
        op0_rst(self);
        return;
    }

    if (self.timing == 3 or self.timing == 4 or self.timing == 5) {
        self.s, _ = @subWithOverflow(self.s, 1);
    }

    interrupt_handler(self, 0xFFFC);
}

fn int_irq(self: *CPU) void {
    if (self.phi == 0) {
        op0_brk(self);
        return;
    }

    if (self.timing == 4) {
        self.p.i = 1;
    }

    interrupt_handler(self, 0xFFFE);
}

fn int_nmi(self: *CPU) void {
    if (self.phi == 0) {
        op0_brk(self);
        return;
    }

    interrupt_handler(self, 0xFFFA);
}

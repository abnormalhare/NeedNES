const std = @import("std");

const CPU = @import("cpu.zig").CPU;

const get_bits = @import("../global.zig").get_bits;
const get_bit = @import("../global.zig").get_bit;

const op0 = @import("op0.zig");

// helper functions

pub fn op_none(self: *CPU) void {
    _ = self;
}

pub fn op_nop(self: *CPU) void {
    op0.timing_check(self, 2);
}

pub fn op_branch(self: *CPU, operation: bool) void {
    if (self.phi == 0) {
        op0.b(self);
        return;
    }

    switch (self.timing) {
        else => {},
        2 => if (!operation) {
            self.timing = 0;
        } else {
            self.adl = self.data;
        },
        3 => {
            const check: bool = self.adl >= 0x80;
            self.adl, self.add = @addWithOverflow(self.adl, @as(u8, @truncate(self.pc)));
            if (check and self.add == 1) self.add = 0xFF;

            self.pc &= 0xFF00;
            self.pc |= self.adl;
            if (self.add == 0) {
                self.timing = 0;
            }
        },
        0 => {
            if (self.add == 1) {
                self.pc, _ = @addWithOverflow(self.pc, 0x100);
            } else {
                self.pc, _ = @subWithOverflow(self.pc, 0x100);
            }
        },
    }
}

// ops

// BRK
pub fn op_00(self: *CPU) void {
    switch (self.timing) {
        else => {},
    }
}

pub fn op_18(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.p.c = 0;
    }
}

// JSR
pub fn op_20(self: *CPU) void {
    op0.timing_check(self, 6);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read_pc() else {
            self.adl = self.data;
            self.addr = 0x100 + @as(u16, self.s);
        },
        3 => if (self.phi == 0) self.read() else {
            self.data = @truncate(self.pc);
        },
        4 => if (self.phi == 0) self.write_stack() else {
            self.data = @truncate(self.pc >> 8);
            self.addr = 0x100 + @as(u16, self.s);
        },
        5 => if (self.phi == 0) self.write_stack(),
        0 => if (self.phi == 0) self.read_pc() else {
            self.pc = self.adl;
            self.pc += @as(u16, self.data) << 8;
        },
    }
}

// BIT X
pub fn op_24(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    switch (self.timing) {
        else => {},
        2 => self.addr = @intCast(self.data),
        0 => {
            const check: u8 = self.a & self.data;

            self.p.z = @intFromBool(check == 0);
            self.p.v = get_bit(check, 6);
            self.p.n = get_bit(check, 7);
        },
    }
}

// SEC
pub fn op_38(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.p.c = 1;
    }
}

// JMP AA
pub fn op_4C(self: *CPU) void {
    op0.timing_check(self, 3);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read_pc() else {
            self.adl = self.data;
        },
        0 => if (self.phi == 0) self.read_pc() else {
            self.pc = @intCast(self.adl);
            self.pc += @as(u16, self.data) << 8;
        },
    }
}

// BVC
pub fn op_50(self: *CPU) void {
    op_branch(self, self.p.v == 0);
}

// JMP (AA)
pub fn op_6C(self: *CPU) void {
    op0.timing_check(self, 5);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read_pc() else {
            self.adl = self.data;
        },
        3 => if (self.phi == 0) self.read_pc() else {
            self.addr = @intCast(self.adl);
            self.addr += @as(u16, self.data) << 8;
        },
        4 => if (self.phi == 0) {
            self.pc += 1;
            self.read();
        } else {
            self.adl = self.data;
        },
        0 => if (self.phi == 0) {
            self.addr += 1;
            self.read();
        } else {
            self.pc = @intCast(self.adl);
            self.pc += @as(u16, self.data) << 8;
        },
    }
}

// BVS
pub fn op_70(self: *CPU) void {
    op_branch(self, self.p.v == 1);
}

// STA X
pub fn op_85(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_w(self);
        return;
    }

    if (self.timing == 2) {
        self.addr = self.data;
        self.data = self.a;
    }
}

// STX X
pub fn op_86(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_w(self);
        return;
    }

    if (self.timing == 2) {
        self.addr = self.data;
        self.data = self.x;
    }
}

// BCC X
pub fn op_90(self: *CPU) void {
    op_branch(self, self.p.c == 0);
}

// LDX #X
pub fn op_A2(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.x = self.data;

        self.p.z = @intFromBool(self.x == 0);
        self.p.n = get_bit(self.x, 7);
    }
}

// LDA #X
pub fn op_A9(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.a = self.data;

        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
}

// BCS X
pub fn op_B0(self: *CPU) void {
    op_branch(self, self.p.c == 1);
}

// BNE
pub fn op_D0(self: *CPU) void {
    op_branch(self, self.p.z == 0);
}

// NOP
pub fn op_EA(self: *CPU) void {
    op_nop(self);
}

// BEQ
pub fn op_F0(self: *CPU) void {
    op_branch(self, self.p.z == 1);
}

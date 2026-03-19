const std = @import("std");

const CPU = @import("cpu.zig").CPU;

const get_bits = @import("../global.zig").get_bits;
const get_bit = @import("../global.zig").get_bit;

const op0 = @import("op0.zig");
const op1 = @import("op1.zig");

// helper functions

pub fn op_none(self: *CPU) void {
    if (self.timing == 2 and self.phi == 0) {
        std.debug.print("UH OH! Skipped Opcode @ {X:0>4} : {X:0>2}\n", .{ self.pc - 1, self.ir });
    }
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
    op0.timing_check(self, 7);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read_pc() else {
            self.addr = 0x100 + @as(u16, self.s);
            self.data = @truncate(self.pc >> 8);
        },
        3 => if (self.phi == 0) self.write_stack() else {
            self.addr = 0x100 + @as(u16, self.s);
            self.data = @truncate(self.pc);
        },
        4 => if (self.phi == 0) self.write_stack() else {
            self.addr = 0x100 + @as(u16, self.s);
            self.p.i = 1;
            self.p.b = 1;
            self.data = self.p.to_num();
            self.p.b = 0;
        },
        5 => if (self.phi == 0) self.write_stack() else {
            self.addr = 0xFFFE;
        },
        6 => if (self.phi == 0) self.read() else {
            self.adl = self.data;
            self.addr += 1;
        },
        0 => if (self.phi == 0) self.read() else {
            self.pc = self.adl;
            self.pc += @as(u16, self.data) << 8;
        },
    }
}

// ORA (d,X)
pub fn op_01(self: *CPU) void {
    if (self.phi == 0) {
        op0.xi_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.indexed_indirect(self);
        return;
    }

    self.a |= self.data;

    self.p.z = @intFromBool(self.a == 0);
    self.p.n = get_bit(self.a, 7);
}

// ORA X
pub fn op_05(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    self.a |= self.data;

    self.p.z = @intFromBool(self.a == 0);
    self.p.n = get_bit(self.a, 7);
}

// ASL X
pub fn op_06(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_rmw(self);
        return;
    }

    op1.zero_page(self);

    if (self.timing == 4) {
        self.data, self.p.c = @shlWithOverflow(self.data, 1);

        self.p.z = @intFromBool(self.data == 0);
        self.p.n = get_bit(self.data, 7);
    }
}

// PHP
pub fn op_08(self: *CPU) void {
    op0.timing_check(self, 3);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read() else {
            self.addr = 0x100 + @as(u16, self.s);
            self.p.b = 1;
            self.data = self.p.to_num();
            self.p.b = 0;
        },
        0 => if (self.phi == 0) self.write_stack(),
    }
}

// ORA #X
pub fn op_09(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.a |= self.data;

        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
}

// ASL
pub fn op_0A(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.a, self.p.c = @shlWithOverflow(self.a, 1);

        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
}

// BPL
pub fn op_10(self: *CPU) void {
    op_branch(self, self.p.n == 0);
}

// CLC
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
            self.data = @truncate(self.pc >> 8);
        },
        4 => if (self.phi == 0) self.write_stack() else {
            self.data = @truncate(self.pc);
            self.addr = 0x100 + @as(u16, self.s);
        },
        5 => if (self.phi == 0) self.write_stack(),
        0 => if (self.phi == 0) self.read_pc() else {
            self.pc = self.adl;
            self.pc += @as(u16, self.data) << 8;
        },
    }
}

// AND (d,X)
pub fn op_21(self: *CPU) void {
    if (self.phi == 0) {
        op0.xi_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.indexed_indirect(self);
        return;
    }

    self.a &= self.data;

    self.p.z = @intFromBool(self.a == 0);
    self.p.n = get_bit(self.a, 7);
}

// BIT X
pub fn op_24(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    const check: u8 = self.a & self.data;
    self.p.z = @intFromBool(check == 0);
    self.p.v = get_bit(self.data, 6);
    self.p.n = get_bit(self.data, 7);
}

// AND X
pub fn op_25(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    self.a &= self.data;

    self.p.z = @intFromBool(self.a == 0);
    self.p.n = get_bit(self.a, 7);
}

// ROL X
pub fn op_26(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_rmw(self);
        return;
    }

    op1.zero_page(self);

    if (self.timing == 4) {
        self.data, const carry = @shlWithOverflow(self.data, 1);
        self.data += @intCast(self.p.c);

        self.p.c = carry;
        self.p.z = @intFromBool(self.data == 0);
        self.p.n = get_bit(self.data, 7);
    }
}

// PLP
pub fn op_28(self: *CPU) void {
    op0.timing_check(self, 4);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read(),
        3 => if (self.phi == 0) self.read_stack() else {
            self.s, _ = @addWithOverflow(self.s, 1);
        },
        0 => if (self.phi == 0) self.read_stack() else {
            self.p.set_num(self.data);
        },
    }
}

// AND #X
pub fn op_29(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.a &= self.data;

        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
}

// ROL
pub fn op_2A(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.a, const carry = @shlWithOverflow(self.a, 1);
        self.a += @intCast(self.p.c);

        self.p.c = carry;
        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
}

// BMI
pub fn op_30(self: *CPU) void {
    op_branch(self, self.p.n == 1);
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

// RTI
pub fn op_40(self: *CPU) void {
    op0.timing_check(self, 6);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read(),
        3 => if (self.phi == 0) self.read_stack() else {
            self.s, _ = @addWithOverflow(self.s, 1);
        },
        4 => if (self.phi == 0) self.read_stack() else {
            self.s, _ = @addWithOverflow(self.s, 1);
            self.p.set_num(self.data);
        },
        5 => if (self.phi == 0) self.read_stack() else {
            self.s, _ = @addWithOverflow(self.s, 1);
            self.pc &= 0xFF00;
            self.pc |= self.data;
        },
        0 => if (self.phi == 0) self.read_stack() else {
            self.pc &= 0x00FF;
            self.pc |= @as(u16, self.data) << 8;
        },
    }
}

// EOR (d,X)
pub fn op_41(self: *CPU) void {
    if (self.phi == 0) {
        op0.xi_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.indexed_indirect(self);
        return;
    }

    self.a ^= self.data;

    self.p.z = @intFromBool(self.a == 0);
    self.p.n = get_bit(self.a, 7);
}

// EOR X
pub fn op_45(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    self.a ^= self.data;

    self.p.z = @intFromBool(self.a == 0);
    self.p.n = get_bit(self.a, 7);
}

// LSR X
pub fn op_46(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_rmw(self);
        return;
    }

    op1.zero_page(self);

    if (self.timing == 4) {
        self.p.c = @intCast(self.data & 1);

        self.data >>= 1;

        self.p.z = @intFromBool(self.data == 0);
        self.p.n = 0;
    }
}

// PHA
pub fn op_48(self: *CPU) void {
    op0.timing_check(self, 3);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read() else {
            self.addr = 0x100 + @as(u16, self.s);
            self.data = self.a;
        },
        0 => if (self.phi == 0) self.write_stack(),
    }
}

// EOR #X
pub fn op_49(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.a ^= self.data;

        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
}

// LSR
pub fn op_4A(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.p.c = @intCast(self.a & 1);

        self.a >>= 1;

        self.p.z = @intFromBool(self.a == 0);
        self.p.n = 0;
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

// RTS
pub fn op_60(self: *CPU) void {
    op0.timing_check(self, 6);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read(),
        3 => if (self.phi == 0) self.read_stack() else {
            self.s, _ = @addWithOverflow(self.s, 1);
        },
        4 => if (self.phi == 0) self.read_stack() else {
            self.s, _ = @addWithOverflow(self.s, 1);
            self.pc &= 0xFF00;
            self.pc |= self.data;
        },
        5 => if (self.phi == 0) self.read_stack() else {
            self.pc &= 0x00FF;
            self.pc |= @as(u16, self.data) << 8;
        },
        0 => if (self.phi == 0) self.read_pc(),
    }
}

// ADC (d,X)
pub fn op_61(self: *CPU) void {
    if (self.phi == 0) {
        op0.xi_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.indexed_indirect(self);
        return;
    }

    const res: u16 = @as(u16, self.a) + @as(u16, self.data) + @as(u16, self.p.c);
    const a = self.a;

    self.a = @truncate(res);

    self.p.c = @intFromBool(res > 0xFF);
    self.p.z = @intFromBool(self.a == 0);
    self.p.v = @intFromBool(((self.a ^ a) & (self.a ^ self.data) & 0x80) == 0x80);
    self.p.n = get_bit(self.a, 7);
}

// ADC X
pub fn op_65(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    const res: u16 = @as(u16, self.a) + @as(u16, self.data) + @as(u16, self.p.c);
    const a = self.a;

    self.a = @truncate(res);

    self.p.c = @intFromBool(res > 0xFF);
    self.p.z = @intFromBool(self.a == 0);
    self.p.v = @intFromBool(((self.a ^ a) & (self.a ^ self.data) & 0x80) == 0x80);
    self.p.n = get_bit(self.a, 7);
}

// ROR X
pub fn op_66(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_rmw(self);
        return;
    }

    op1.zero_page(self);

    if (self.timing == 4) {
        const carry: u1 = @intCast(self.data & 1);
        self.data >>= 1;
        self.data += @as(u8, self.p.c) * 0x80;

        self.p.c = carry;
        self.p.z = @intFromBool(self.data == 0);
        self.p.n = get_bit(self.data, 7);
    }
}

// PLA
pub fn op_68(self: *CPU) void {
    op0.timing_check(self, 4);

    switch (self.timing) {
        else => {},
        2 => if (self.phi == 0) self.read(),
        3 => if (self.phi == 0) self.read_stack() else {
            self.s, _ = @addWithOverflow(self.s, 1);
        },
        0 => if (self.phi == 0) self.read_stack() else {
            self.a = self.data;

            self.p.z = @intFromBool(self.a == 0);
            self.p.n = get_bit(self.a, 7);
        },
    }
}

// ADC #X
pub fn op_69(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);

        const res: u16 = @as(u16, self.a) + @as(u16, self.data) + @as(u16, self.p.c);
        const a = self.a;

        self.a = @truncate(res);

        self.p.c = @intFromBool(res > 0xFF);
        self.p.z = @intFromBool(self.a == 0);
        self.p.v = @intFromBool(((self.a ^ a) & (self.a ^ self.data) & 0x80) == 0x80);
        self.p.n = get_bit(self.a, 7);
    }
}

// ROR
pub fn op_6A(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        const carry: u1 = @intCast(self.a & 1);
        self.a >>= 1;
        self.a += @as(u8, self.p.c) * 0x80;

        self.p.c = carry;
        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
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

// SEI
pub fn op_78(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.p.i = 1;
    }
}

// STA (d,X)
pub fn op_81(self: *CPU) void {
    if (self.phi == 0) {
        op0.xi_w(self);
        return;
    }

    op1.indexed_indirect(self);

    if (self.timing == 5) {
        self.data = self.a;
    }
}

// STY X
pub fn op_84(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_w(self);
        return;
    }

    op1.zero_page(self);

    if (self.timing == 2) {
        self.data = self.y;
    }
}

// STA X
pub fn op_85(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_w(self);
        return;
    }

    op1.zero_page(self);

    if (self.timing == 2) {
        self.data = self.a;
    }
}

// STX X
pub fn op_86(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_w(self);
        return;
    }

    op1.zero_page(self);

    if (self.timing == 2) {
        self.data = self.x;
    }
}

// DEY
pub fn op_88(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.y, _ = @subWithOverflow(self.y, 1);

        self.p.z = @intFromBool(self.y == 0);
        self.p.n = get_bit(self.y, 7);
    }
}

// TXA
pub fn op_8A(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.a = self.x;

        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
}

// STA XX
pub fn op_8D(self: *CPU) void {
    if (self.phi == 0) {
        op0.a_w(self);
        return;
    }

    op1.absolute(self);

    if (self.timing == 3) {
        self.data = self.a;
    }
}

// STX XX
pub fn op_8E(self: *CPU) void {
    if (self.phi == 0) {
        op0.a_w(self);
        return;
    }

    op1.absolute(self);

    if (self.timing == 3) {
        self.data = self.x;
    }
}

// BCC
pub fn op_90(self: *CPU) void {
    op_branch(self, self.p.c == 0);
}

// TYA
pub fn op_98(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.a = self.y;

        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
}

// TXS
pub fn op_9A(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.s = self.x;
    }
}

// LDY #X
pub fn op_A0(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.y = self.data;

        self.p.z = @intFromBool(self.y == 0);
        self.p.n = get_bit(self.y, 7);
    }
}

// LDA (d,X)
pub fn op_A1(self: *CPU) void {
    if (self.phi == 0) {
        op0.xi_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.indexed_indirect(self);
        return;
    }

    self.a = self.data;

    self.p.z = @intFromBool(self.a == 0);
    self.p.n = get_bit(self.a, 7);
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

// LDY X
pub fn op_A4(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    self.y = self.data;

    self.p.z = @intFromBool(self.y == 0);
    self.p.n = get_bit(self.y, 7);
}

// LDA X
pub fn op_A5(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    self.a = self.data;

    self.p.z = @intFromBool(self.a == 0);
    self.p.n = get_bit(self.a, 7);
}

// LDX X
pub fn op_A6(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    self.x = self.data;

    self.p.z = @intFromBool(self.x == 0);
    self.p.n = get_bit(self.x, 7);
}

// TAY
pub fn op_A8(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.y = self.a;

        self.p.z = @intFromBool(self.y == 0);
        self.p.n = get_bit(self.y, 7);
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

// TAX
pub fn op_AA(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.x = self.a;

        self.p.z = @intFromBool(self.x == 0);
        self.p.n = get_bit(self.x, 7);
    }
}

// LDA XX
pub fn op_AD(self: *CPU) void {
    if (self.phi == 0) {
        op0.a_r(self);
        return;
    }

    op1.absolute(self);

    if (self.timing == 0) {
        self.a = self.data;

        self.p.z = @intFromBool(self.a == 0);
        self.p.n = get_bit(self.a, 7);
    }
}

// LDX
pub fn op_AE(self: *CPU) void {
    if (self.phi == 0) {
        op0.a_r(self);
        return;
    }

    op1.absolute(self);

    if (self.timing == 0) {
        self.x = self.data;

        self.p.z = @intFromBool(self.x == 0);
        self.p.n = get_bit(self.x, 7);
    }
}

// BCS
pub fn op_B0(self: *CPU) void {
    op_branch(self, self.p.c == 1);
}

// CLV
pub fn op_B8(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.p.v = 0;
    }
}

// TSX
pub fn op_BA(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.x = self.s;

        self.p.z = @intFromBool(self.x == 0);
        self.p.n = get_bit(self.x, 7);
    }
}

// CPY #X
pub fn op_C0(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        const res: u8, _ = @subWithOverflow(self.y, self.data);

        self.p.c = @intFromBool(self.y >= self.data);
        self.p.z = @intFromBool(self.y == self.data);
        self.p.n = get_bit(res, 7);
    }
}

// CMP (d,X)
pub fn op_C1(self: *CPU) void {
    if (self.phi == 0) {
        op0.xi_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.indexed_indirect(self);
        return;
    }

    const res: u8, _ = @subWithOverflow(self.a, self.data);

    self.p.c = @intFromBool(self.a >= self.data);
    self.p.z = @intFromBool(self.a == self.data);
    self.p.n = get_bit(res, 7);
}

// CPY X
pub fn op_C4(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    const res: u8, _ = @subWithOverflow(self.y, self.data);

    self.p.c = @intFromBool(self.y >= self.data);
    self.p.z = @intFromBool(self.y == self.data);
    self.p.n = get_bit(res, 7);
}

// CMP X
pub fn op_C5(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    const res: u8, _ = @subWithOverflow(self.a, self.data);

    self.p.c = @intFromBool(self.a >= self.data);
    self.p.z = @intFromBool(self.a == self.data);
    self.p.n = get_bit(res, 7);
}

// DEC X
pub fn op_C6(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_rmw(self);
        return;
    }

    op1.zero_page(self);

    if (self.timing == 4) {
        self.data, _ = @subWithOverflow(self.data, 1);

        self.p.z = @intFromBool(self.data == 0);
        self.p.n = get_bit(self.data, 7);
    }
}

// INY
pub fn op_C8(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.y, _ = @addWithOverflow(self.y, 1);

        self.p.z = @intFromBool(self.y == 0);
        self.p.n = get_bit(self.y, 7);
    }
}

// DEX
pub fn op_CA(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.x, _ = @subWithOverflow(self.x, 1);

        self.p.z = @intFromBool(self.x == 0);
        self.p.n = get_bit(self.x, 7);
    }
}

// CMP #X
pub fn op_C9(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        const res: u8, _ = @subWithOverflow(self.a, self.data);

        self.p.c = @intFromBool(self.a >= self.data);
        self.p.z = @intFromBool(self.a == self.data);
        self.p.n = get_bit(res, 7);
    }
}

// BNE
pub fn op_D0(self: *CPU) void {
    op_branch(self, self.p.z == 0);
}

// CLD
pub fn op_D8(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.p.d = 0;
    }
}

// CPX #X
pub fn op_E0(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        const res: u8, _ = @subWithOverflow(self.x, self.data);

        self.p.c = @intFromBool(self.x >= self.data);
        self.p.z = @intFromBool(self.x == self.data);
        self.p.n = get_bit(res, 7);
    }
}

// SBC (d,X)
pub fn op_E1(self: *CPU) void {
    if (self.phi == 0) {
        op0.xi_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.indexed_indirect(self);
        return;
    }

    var res: u16 = @intCast(self.a);
    res, const uf_temp = @subWithOverflow(res, self.data);
    res, const uf_temp2 = @subWithOverflow(res, ~self.p.c);

    const underflow = uf_temp | uf_temp2;

    const a = self.a;
    self.a = @truncate(res);

    self.p.c = ~underflow;
    self.p.z = @intFromBool(self.a == 0);
    self.p.v = @intFromBool(((self.a ^ a) & (self.a ^ ~self.data) & 0x80) == 0x80);
    self.p.n = get_bit(self.a, 7);
}

// CPX X
pub fn op_E4(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    const res: u8, _ = @subWithOverflow(self.x, self.data);

    self.p.c = @intFromBool(self.x >= self.data);
    self.p.z = @intFromBool(self.x == self.data);
    self.p.n = get_bit(res, 7);
}

// SBC X
pub fn op_E5(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_r(self);
        return;
    }

    if (self.timing != 0) {
        op1.zero_page(self);
        return;
    }

    var res: u16 = @intCast(self.a);
    res, const uf_temp = @subWithOverflow(res, self.data);
    res, const uf_temp2 = @subWithOverflow(res, ~self.p.c);

    const underflow = uf_temp | uf_temp2;

    const a = self.a;
    self.a = @truncate(res);

    self.p.c = ~underflow;
    self.p.z = @intFromBool(self.a == 0);
    self.p.v = @intFromBool(((self.a ^ a) & (self.a ^ ~self.data) & 0x80) == 0x80);
    self.p.n = get_bit(self.a, 7);
}

// INC X
pub fn op_E6(self: *CPU) void {
    if (self.phi == 0) {
        op0.z_rmw(self);
        return;
    }

    op1.zero_page(self);

    if (self.timing == 4) {
        self.data, _ = @addWithOverflow(self.data, 1);

        self.p.z = @intFromBool(self.data == 0);
        self.p.n = get_bit(self.data, 7);
    }
}

// INX
pub fn op_E8(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.x, _ = @addWithOverflow(self.x, 1);

        self.p.z = @intFromBool(self.x == 0);
        self.p.n = get_bit(self.x, 7);
    }
}

// SBC #X
pub fn op_E9(self: *CPU) void {
    if (self.phi == 0) {
        op0.imm(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        var res: u16 = @intCast(self.a);
        res, const uf_temp = @subWithOverflow(res, self.data);
        res, const uf_temp2 = @subWithOverflow(res, ~self.p.c);

        const underflow = uf_temp | uf_temp2;

        const res_sign: u1 = get_bit(@truncate(res), 7);
        const a_sign: u1 = get_bit(@intCast(self.a), 7);
        const data_sign: u1 = get_bit(@intCast(self.data), 7);

        self.a = @truncate(res);

        self.p.c = ~underflow;
        self.p.z = @intFromBool(self.a == 0);
        self.p.v = @intFromBool(res_sign != a_sign and res_sign == data_sign);
        self.p.n = get_bit(self.a, 7);
    }
}

// NOP
pub fn op_EA(self: *CPU) void {
    op_nop(self);
}

// BEQ
pub fn op_F0(self: *CPU) void {
    op_branch(self, self.p.z == 1);
}

// SED
pub fn op_F8(self: *CPU) void {
    if (self.phi == 0) {
        op0.imp(self);
        return;
    }

    if (self.timing == 0) {
        @branchHint(.likely);
        self.p.d = 1;
    }
}

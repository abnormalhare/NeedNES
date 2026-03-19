const CPU = @import("cpu.zig").CPU;

pub fn indexed_indirect(self: *CPU) void {
    switch (self.timing) {
        else => {},
        2 => self.addr = self.data,
        3 => {
            const zero: u8 = @truncate(self.addr);
            self.addr, _ = @addWithOverflow(zero, self.x);
        },
        4 => {
            self.adl = self.data;
            const zero: u8 = @truncate(self.addr);
            self.addr, _ = @addWithOverflow(zero, 1);
        },
        5 => {
            self.addr = self.adl;
            self.addr += @as(u16, self.data) << 8;
        },
    }
}

pub fn absolute(self: *CPU) void {
    switch (self.timing) {
        else => {},
        2 => self.adl = self.data,
        3 => {
            self.addr = self.adl;
            self.addr += @as(u16, self.data) << 8;
        },
    }
}

const CPU = @import("cpu.zig").CPU;

pub fn indexed_indirect(self: *CPU) void {
    switch (self.timing) {
        else => {},
        2 => self.addr = self.data,
        3 => self.addr += self.x,
        4 => {
            self.adl = self.data;
            self.addr += 1;
        },
        5 => {
            self.addr = self.adl;
            self.addr += @as(u16, self.data) << 8;
        },
    }
}

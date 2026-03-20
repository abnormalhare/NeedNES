const CPU = @import("cpu.zig").CPU;

/// r: 0, rmw: 7, w: 5
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

/// r: 0 rmw: 7, w: 5
pub fn indirect_indexed(self: *CPU, read: bool) void {
    switch (self.timing) {
        else => {},
        2 => self.addr = self.data,
        3 => {
            self.adl = self.data;
            const temp: u8 = @truncate(self.addr);
            self.addr, _ = @addWithOverflow(temp, 1);
        },
        4 => {
            const temp: u8, self.add = @addWithOverflow(self.adl, self.y);
            self.addr = temp;
            self.addr += @as(u16, self.data) << 8;
            if (read and self.add == 0) self.timing = 5;
        },
        5 => {
            self.addr, _ = @addWithOverflow(self.addr, @as(u16, self.add) * 0x100);
        },
    }
}

/// r: 0, rmw: 5, w: 3
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

const Index = enum { x, y };

/// r: 0 rmw: 6, w: 4
pub fn absolute_indexed(self: *CPU, index: Index, read: bool) void {
    switch (self.timing) {
        else => {},
        2 => self.adl = self.data,
        3 => {
            self.addr = self.adl;
            self.addr += @as(u16, self.data) << 8;
            const addr: u8 = @truncate(self.addr);
            const res, self.add = @addWithOverflow(addr, switch (index) {
                .x => self.x,
                .y => self.y,
            });
            self.addr &= 0xFF00;
            self.addr |= res;
            if (read and self.add == 0) {
                self.timing = 4;
            }
        },
        4 => {
            self.addr, _ = @addWithOverflow(self.addr, @as(u16, self.add) * 0x100);
        },
    }
}

/// r: 0, rmw: 4, w: 2
pub fn zero_page(self: *CPU) void {
    switch (self.timing) {
        else => {},
        2 => self.addr = self.data,
    }
}

/// r: 0 rmw: 5, w: 3
pub fn zero_page_indexed(self: *CPU, index: Index) void {
    switch (self.timing) {
        else => {},
        2 => self.addr = self.data,
        3 => {
            const addr: u8 = @truncate(self.addr);
            const res: u8, _ = @addWithOverflow(addr, switch (index) {
                .x => self.x,
                .y => self.y,
            });

            self.addr = res;
        },
    }
}

const std = @import("std");

const ReadWrite = @import("../global.zig").ReadWrite;

pub const VRAM = struct {
    // externally manipulated
    addr: u11,
    rw: ReadWrite,
    chip_enable: u1,
    phi: u1,
    latch: u8,

    data: [0x800]u8,

    // this unfortunately relies on being called AFTER CPU because it is technically activated between PHI1 and PHI2.
    pub fn tick(self: *VRAM) void {
        if (self.phi != 0 or self.chip_enable == 0) return;

        switch (self.rw) {
            .write => self.data[self.addr] = self.latch,
            .read => self.latch = self.data[self.addr],
        }
    }

    pub fn to_next_state(self: *VRAM) void {
        const next = self.next_state;

        self.data = next.data;
    }

    pub fn new() VRAM {
        const self: VRAM = .{
            .data = [_]u8{0} ** 0x800,
            .addr = 0,
            .rw = .write,
            .chip_enable = 0,
            .phi = 0,
            .latch = 0,
        };

        return self;
    }
};

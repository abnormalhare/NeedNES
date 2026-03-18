const std = @import("std");

const MapperInfo = @import("../global.zig").MapperInfo;

const Error = error{ BadPRGROM, BadCHRROM, BadPRGRAM };

pub const NROM = struct {
    prg_rom: [0x8000]u8,
    prg_rom_size: u16,
    chr_rom: [0x4000]u8,
    chr_rom_size: u16,
    prg_ram: [0x1000]u8,
    prg_ram_size: u16,

    latch: ?u8,

    pub fn read_cpu(self: *NROM, update: u1, addr: u16) ?u8 {
        if (update == 0) {
            switch (addr) {
                0x6000...0x7FFF => self.latch = if (self.prg_ram_size == 0) null else self.prg_ram[addr % self.prg_ram_size],
                0x8000...0xFFFF => self.latch = self.prg_rom[addr % self.prg_rom_size],
                else => self.latch = null,
            }

            return null;
        } else {
            return self.latch;
        }
    }

    pub fn read_ppu(self: *NROM, update: u1, addr: u16) ?u8 {
        if (update == 0) {
            switch (addr) {
                0x0000...0x1FFF => self.latch = self.chr_rom[addr % self.chr_rom_size],
                else => self.latch = null,
            }

            return null;
        } else {
            return self.latch;
        }
    }

    pub fn write_cpu(self: *NROM, addr: u16, data: u8) void {
        switch (addr) {
            0x6000...0x7FFF => if (self.prg_ram_size != 0) {
                self.prg_ram[addr % self.prg_ram_size] = data;
            },
            else => {},
        }
    }

    pub fn write_ppu(self: *NROM, addr: u16, data: u8) void {
        _ = self;
        _ = addr;
        _ = data;
    }

    pub fn new(alloc: std.mem.Allocator, rom: *[]u8, info: MapperInfo) !*NROM {
        const self = try alloc.create(NROM);
        errdefer alloc.destroy(self);

        if (info.prg_rom > 2) {
            std.debug.print("Invalid PRG ROM Size: {d}\n", .{info.prg_rom});
            return Error.BadPRGROM;
        }
        self.prg_rom_size = @as(u16, info.prg_rom) * 0x4000;

        if (info.chr_rom > 2) {
            std.debug.print("Invalid CHR ROM Size: {d}\n", .{info.chr_rom});
            return Error.BadCHRROM;
        }
        self.chr_rom_size = @as(u16, info.chr_rom) * 0x2000;

        if (info.prg_ram != 0) {
            if (info.header_type == .nes2 and (info.prg_ram < 5 or info.prg_ram > 6) or (info.prg_ram != 1)) {
                std.debug.print("Invalid PRG RAM Size: {d}\n", .{info.prg_ram});
                return Error.BadPRGRAM;
            }
        }

        if (info.header_type == .nes2) {
            self.prg_ram_size = @as(u16, 0x40) << @truncate(info.prg_ram);
        } else {
            self.prg_ram_size = 0x1000;
        }

        @memcpy(self.prg_rom[0..self.prg_rom_size], rom.*[0..self.prg_rom_size]);
        @memcpy(self.chr_rom[0..self.chr_rom_size], rom.*[self.prg_rom_size..(self.prg_rom_size + self.chr_rom_size)]);

        return self;
    }
};

const std = @import("std");

const NROM = @import("000_nrom.zig").NROM;

const MapperInfo = @import("../global.zig").MapperInfo;

pub const Mapper = union(enum) {
    nrom: *NROM,

    pub fn read_cpu(self: Mapper, update: u1, addr: u16) ?u8 {
        return switch (self) {
            inline else => |s| s.read_cpu(update, addr),
        };
    }

    pub fn read_ppu(self: Mapper, update: u1, addr: u16) ?u8 {
        return switch (self) {
            inline else => |s| s.read_ppu(update, addr),
        };
    }

    pub fn write_cpu(self: Mapper, addr: u16, data: u8) void {
        return switch (self) {
            inline else => |s| s.write_cpu(addr, data),
        };
    }

    pub fn write_ppu(self: Mapper, addr: u16, data: u8) void {
        return switch (self) {
            inline else => |s| s.write_ppu(addr, data),
        };
    }

    pub fn new(alloc: std.mem.Allocator, comptime mapper: type, rom: *[]u8, info: MapperInfo) !Mapper {
        const self: Mapper = switch (mapper) {
            NROM => .{ .nrom = try NROM.new(alloc, rom, info) },
            else => @compileError("Mapper " ++ @typeName(mapper) ++ "is unsupported."),
        };

        return self;
    }

    pub fn deinit(self: Mapper, alloc: std.mem.Allocator) void {
        switch (self) {
            inline else => |s| alloc.destroy(s),
        }
    }
};

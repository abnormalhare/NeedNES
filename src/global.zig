const std = @import("std");
const zsdl = @import("zsdl2");
const zsdl_ttf = @import("zsdl2_ttf");

pub const ReadWrite = enum {
    write,
    read,
};

const HeaderType = enum { ines, nes2 };
const NametableMirroring = enum(u8) { horiz, vert, custom };
const ConsoleType = enum(u8) { NES, VsSystem, PC10, custom };
const RefreshType = enum(u8) { ntsc, pal, dendy, multi };
const VsPPUType = enum(u8) { Rx2C03, RP2C04_1, RP2C04_2, RP2C04_3, RP2C04_4, RC2C05_1, RC2C05_2, RC2C05_3, RC2C05_4 };
const VsHardwareType = enum(u8) { Uni, UniBaseball, UniBoxing, UniXevious, UniIceClimber, Dual, DualRaid };
const ExtConsoleType = enum(u8) { NES, VsSystem, PC10, Famiclone, NES_EPSM, VT1, VT2, VT3, VT9, VT32, VT369, UM6578, FNS };

pub const MapperInfo = struct {
    prg_rom: u12, // 4 (+ 9 NES 2.0)
    chr_rom: u12, // 5 (+ 9 NES 2.0)

    // byte 6
    nametable: NametableMirroring,
    has_persistent_mem: bool,
    has_trainer: bool,

    // byte 7
    console_type: ConsoleType,
    header_type: HeaderType,

    // byte 9 & 10 iNES | byte C NES 2.0
    refresh_type: RefreshType,
    has_bus_conflict: bool,

    // byte 6, 7 (+ 8 NES 2.0)
    mapper: u12,
    submapper: u4,

    // byte 8 iNES | A NES 2.0
    prg_ram: u8,
    prg_nvram: u4,

    // byte B NES 2.0
    chr_ram: u4,
    chr_nvram: u4,

    // byte D NES 2.0
    vs_ppu_type: VsPPUType,
    vs_hardware_type: VsHardwareType,
    ext_console_type: ExtConsoleType,

    // byte E
    rom_count: u2,

    // byte F
    device_code: u8,
};

pub const RenderState = struct {
    window: *zsdl.Window,
    renderer: *zsdl.Renderer,
    debug_font: *zsdl_ttf.Font,

    surfaces: std.ArrayList(*zsdl.Surface),
};

pub const TickType = enum {
    none,
    instr,
    clock,
    phase,
};

pub const ProcessResult = enum {
    none,
    unpause,
    pause_type,
};

pub const WINDOW_WIDTH: u16 = 640;
pub const WINDOW_HEIGHT: u16 = 640;

pub const BLACK: zsdl.Color = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
pub const WHITE: zsdl.Color = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };

pub fn get_bits(num: u8, start: u3, end: u3) u8 {
    const mask = @as(u8, 1) << (end - start + 1) - 1;
    return (num >> start) & mask;
}

pub fn get_bit(num: u8, bit: u3) u1 {
    const temp = num & (@as(u8, 1) << bit);
    return @intCast(temp >> bit);
}

pub fn interpret_nes_header(header: []const u8) MapperInfo {
    var info = std.mem.zeroes(MapperInfo);
    var curr_byte: u8 = undefined;

    info.prg_rom = @intCast(header[0]);
    info.chr_rom = @intCast(header[1]);

    curr_byte = header[2];
    info.nametable = if (get_bits(curr_byte, 3, 3) == 1) .custom else @enumFromInt(get_bits(curr_byte, 0, 0));
    info.has_persistent_mem = get_bits(curr_byte, 1, 1) == 1;
    info.has_trainer = get_bits(curr_byte, 2, 2) == 1;
    info.mapper = @intCast(get_bits(curr_byte, 4, 7));

    curr_byte = header[3];
    info.console_type = @enumFromInt(get_bits(curr_byte, 0, 1));
    info.header_type = if (get_bits(curr_byte, 2, 3) == 2) .nes2 else .ines;
    info.mapper += @as(u12, get_bits(curr_byte, 4, 7)) << 4;

    curr_byte = header[4];
    info.mapper += @as(u12, get_bits(curr_byte, 0, 3)) << 8;
    info.submapper = @truncate(get_bits(curr_byte, 4, 7));

    curr_byte = header[5];
    info.prg_rom += @as(u12, get_bits(curr_byte, 0, 3)) << 8;
    info.chr_rom += @as(u12, get_bits(curr_byte, 4, 7)) << 8;

    return info;
}

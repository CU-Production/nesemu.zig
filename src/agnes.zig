// SPDX-License-Identifier: MIT
// agnes NES emulator - Zig port
// Original C version: https://github.com/kgabis/agnes

const std = @import("std");

// Version
pub const VERSION_MAJOR = 0;
pub const VERSION_MINOR = 2;
pub const VERSION_PATCH = 0;
pub const VERSION_STRING = "0.2.0";

// Constants
pub const SCREEN_WIDTH = 256;
pub const SCREEN_HEIGHT = 240;

// Utility macro equivalent
pub inline fn getBit(byte: anytype, bit_ix: anytype) u8 {
    return @intCast((byte >> @intCast(bit_ix)) & 1);
}

// ================================
// Type Definitions
// ================================

pub const Input = extern struct {
    a: bool,
    b: bool,
    select: bool,
    start: bool,
    up: bool,
    down: bool,
    left: bool,
    right: bool,
};

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// CPU Interrupt types
const CpuInterrupt = enum(u8) {
    none = 0,
    nmi = 1,
    irq = 2,
};

// CPU Structure
pub const Cpu = struct {
    agnes: *Agnes,
    pc: u16,
    sp: u8,
    acc: u8,
    x: u8,
    y: u8,
    flag_carry: u8,
    flag_zero: u8,
    flag_dis_interrupt: u8,
    flag_decimal: u8,
    flag_overflow: u8,
    flag_negative: u8,
    stall: u32,
    cycles: u64,
    interrupt: CpuInterrupt,
};

// Pulse channel
const PulseChannel = struct {
    enabled: bool,
    duty: u8,
    length_counter_halt: bool,
    constant_volume: bool,
    volume: u8,
    timer_period: u16,
    timer_value: u16,
    length_counter: u8,
    duty_pos: u8,
    envelope_divider: u8,
    envelope_counter: u8,
    envelope_volume: u8,
    sweep_enabled: bool,
    sweep_period: u8,
    sweep_negate: bool,
    sweep_shift: u8,
    sweep_divider: u8,
    sweep_reload: bool,
};

// Triangle channel
const TriangleChannel = struct {
    enabled: bool,
    length_counter_halt: bool,
    timer_period: u16,
    timer_value: u16,
    length_counter: u8,
    sequence_pos: u8,
    linear_counter: u8,
    linear_counter_reload: u8,
    linear_counter_reload_flag: bool,
};

// Noise channel
const NoiseChannel = struct {
    enabled: bool,
    length_counter_halt: bool,
    constant_volume: bool,
    volume: u8,
    mode: bool,
    timer_period: u16,
    timer_value: u16,
    length_counter: u8,
    shift_register: u16,
    envelope_divider: u8,
    envelope_counter: u8,
    envelope_volume: u8,
};

// DMC channel
const DmcChannel = struct {
    enabled: bool,
    sample_address: u16,
    sample_length: u16,
    current_address: u16,
    bytes_remaining: u16,
    sample_buffer: u8,
    sample_buffer_empty: bool,
    shift_register: u8,
    bits_remaining: u8,
    silence: bool,
    timer_period: u16,
    timer_value: u16,
    output_level: u8,
    irq_enabled: bool,
    loop: bool,
};

// APU Structure
const Apu = struct {
    agnes: *Agnes,
    pulse1: PulseChannel,
    pulse2: PulseChannel,
    triangle: TriangleChannel,
    noise: NoiseChannel,
    dmc: DmcChannel,
    frame_counter_mode: u8,
    frame_interrupt_inhibit: bool,
    frame_counter: u32,
    cycles: u32,
    frame_interrupt: bool,
    sample_buffer: [4096]f32,
    sample_write_pos: u32,
    sample_read_pos: u32,
    highpass_prev_in: f32,
    highpass_prev_out: f32,
    lowpass_prev_out: f32,
    sample_accumulator: f32,
};

// Sprite
const Sprite = struct {
    y_pos: u8,
    tile_num: u8,
    attrs: u8,
    x_pos: u8,
};

// PPU Structure
const Ppu = struct {
    agnes: *Agnes,
    nametables: [4 * 1024]u8,
    palette: [32]u8,
    screen_buffer: [SCREEN_HEIGHT * SCREEN_WIDTH]u8,
    scanline: i32,
    dot: i32,
    ppudata_buffer: u8,
    last_reg_write: u8,
    regs: struct {
        v: u16,
        t: u16,
        x: u8,
        w: u8,
    },
    masks: struct {
        show_leftmost_bg: bool,
        show_leftmost_sprites: bool,
        show_background: bool,
        show_sprites: bool,
    },
    nt: u8,
    at: u8,
    at_latch: u8,
    at_shift: u16,
    bg_hi: u8,
    bg_lo: u8,
    bg_hi_shift: u16,
    bg_lo_shift: u16,
    ctrl: struct {
        addr_increment: u16,
        sprite_table_addr: u16,
        bg_table_addr: u16,
        use_8x16_sprites: bool,
        nmi_enabled: bool,
    },
    status: struct {
        in_vblank: bool,
        sprite_overflow: bool,
        sprite_zero_hit: bool,
    },
    is_odd_frame: bool,
    oam_address: u8,
    oam_data: [256]u8,
    sprites: [8]Sprite,
    sprite_ixs: [8]i32,
    sprite_ixs_count: i32,
};

// Mirroring modes
pub const MirroringMode = enum {
    none,
    single_lower,
    single_upper,
    horizontal,
    vertical,
    four_screen,
};

// Mapper 0
const Mapper0 = struct {
    agnes: *Agnes,
    prg_bank_offsets: [2]u32,
    use_chr_ram: bool,
    chr_ram: [8 * 1024]u8,
};

// Mapper 1
const Mapper1 = struct {
    agnes: *Agnes,
    shift: u8,
    shift_count: i32,
    control: u8,
    prg_mode: i32,
    chr_mode: i32,
    chr_banks: [2]i32,
    prg_bank: i32,
    chr_bank_offsets: [2]u32,
    prg_bank_offsets: [2]u32,
    use_chr_ram: bool,
    chr_ram: [8 * 1024]u8,
    prg_ram: [8 * 1024]u8,
};

// Mapper 2
const Mapper2 = struct {
    agnes: *Agnes,
    prg_bank_offsets: [2]u32,
    chr_ram: [8 * 1024]u8,
};

// Mapper 4
const Mapper4 = struct {
    agnes: *Agnes,
    prg_mode: u32,
    chr_mode: u32,
    irq_enabled: bool,
    reg_ix: i32,
    regs: [8]u8,
    counter: u8,
    counter_reload: u8,
    chr_bank_offsets: [8]u32,
    prg_bank_offsets: [4]u32,
    prg_ram: [8 * 1024]u8,
    use_chr_ram: bool,
    chr_ram: [8 * 1024]u8,
};

// Gamepack
const Gamepack = struct {
    data: ?[*]const u8,
    prg_rom_offset: u32,
    chr_rom_offset: u32,
    prg_rom_banks_count: i32,
    chr_rom_banks_count: i32,
    has_prg_ram: bool,
    mapper: u8,
};

// Controller
const Controller = struct {
    state: u8,
    shift: u8,
};

// Main Agnes structure
pub const Agnes = struct {
    cpu: Cpu,
    ppu: Ppu,
    apu: Apu,
    ram: [2 * 1024]u8,
    gamepack: Gamepack,
    controllers: [2]Controller,
    controllers_latch: bool,
    mapper: union {
        m0: Mapper0,
        m1: Mapper1,
        m2: Mapper2,
        m4: Mapper4,
    },
    mirroring_mode: MirroringMode,
};

// Agnes state for save/restore
pub const AgnesState = struct {
    agnes: Agnes,
};

// Address modes for instructions
pub const AddrMode = enum {
    none,
    absolute,
    absolute_x,
    absolute_y,
    accumulator,
    immediate,
    implied,
    implied_brk,
    indirect,
    indirect_x,
    indirect_y,
    relative,
    zero_page,
    zero_page_x,
    zero_page_y,
};

// Instruction structure
const Instruction = struct {
    name: []const u8,
    opcode: u8,
    cycles: u8,
    page_cross_cycle: bool,
    mode: AddrMode,
    operation: ?*const fn (*Cpu, u16, AddrMode) i32,
};

// iNES header
const InesHeader = extern struct {
    magic: [4]u8,
    prg_rom_banks_count: u8,
    chr_rom_banks_count: u8,
    flags_6: u8,
    flags_7: u8,
    prg_ram_banks_count: u8,
    flags_9: u8,
    flags_10: u8,
    zeros: [5]u8,
};

// ================================
// Global Data
// ================================

const palette_addr_map = [32]u32{
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    0x00, 0x11, 0x12, 0x13, 0x04, 0x15, 0x16, 0x17, 0x08, 0x19, 0x1a, 0x1b, 0x0c, 0x1d, 0x1e, 0x1f,
};

const colors = [64]Color{
    .{ .r = 0x7c, .g = 0x7c, .b = 0x7c, .a = 0xff }, .{ .r = 0x00, .g = 0x00, .b = 0xfc, .a = 0xff },
    .{ .r = 0x00, .g = 0x00, .b = 0xbc, .a = 0xff }, .{ .r = 0x44, .g = 0x28, .b = 0xbc, .a = 0xff },
    .{ .r = 0x94, .g = 0x00, .b = 0x84, .a = 0xff }, .{ .r = 0xa8, .g = 0x00, .b = 0x20, .a = 0xff },
    .{ .r = 0xa8, .g = 0x10, .b = 0x00, .a = 0xff }, .{ .r = 0x88, .g = 0x14, .b = 0x00, .a = 0xff },
    .{ .r = 0x50, .g = 0x30, .b = 0x00, .a = 0xff }, .{ .r = 0x00, .g = 0x78, .b = 0x00, .a = 0xff },
    .{ .r = 0x00, .g = 0x68, .b = 0x00, .a = 0xff }, .{ .r = 0x00, .g = 0x58, .b = 0x00, .a = 0xff },
    .{ .r = 0x00, .g = 0x40, .b = 0x58, .a = 0xff }, .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff },
    .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff }, .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff },
    .{ .r = 0xbc, .g = 0xbc, .b = 0xbc, .a = 0xff }, .{ .r = 0x00, .g = 0x78, .b = 0xf8, .a = 0xff },
    .{ .r = 0x00, .g = 0x58, .b = 0xf8, .a = 0xff }, .{ .r = 0x68, .g = 0x44, .b = 0xfc, .a = 0xff },
    .{ .r = 0xd8, .g = 0x00, .b = 0xcc, .a = 0xff }, .{ .r = 0xe4, .g = 0x00, .b = 0x58, .a = 0xff },
    .{ .r = 0xf8, .g = 0x38, .b = 0x00, .a = 0xff }, .{ .r = 0xe4, .g = 0x5c, .b = 0x10, .a = 0xff },
    .{ .r = 0xac, .g = 0x7c, .b = 0x00, .a = 0xff }, .{ .r = 0x00, .g = 0xb8, .b = 0x00, .a = 0xff },
    .{ .r = 0x00, .g = 0xa8, .b = 0x00, .a = 0xff }, .{ .r = 0x00, .g = 0xa8, .b = 0x44, .a = 0xff },
    .{ .r = 0x00, .g = 0x88, .b = 0x88, .a = 0xff }, .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff },
    .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff }, .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff },
    .{ .r = 0xf8, .g = 0xf8, .b = 0xf8, .a = 0xff }, .{ .r = 0x3c, .g = 0xbc, .b = 0xfc, .a = 0xff },
    .{ .r = 0x68, .g = 0x88, .b = 0xfc, .a = 0xff }, .{ .r = 0x98, .g = 0x78, .b = 0xf8, .a = 0xff },
    .{ .r = 0xf8, .g = 0x78, .b = 0xf8, .a = 0xff }, .{ .r = 0xf8, .g = 0x58, .b = 0x98, .a = 0xff },
    .{ .r = 0xf8, .g = 0x78, .b = 0x58, .a = 0xff }, .{ .r = 0xfc, .g = 0xa0, .b = 0x44, .a = 0xff },
    .{ .r = 0xf8, .g = 0xb8, .b = 0x00, .a = 0xff }, .{ .r = 0xb8, .g = 0xf8, .b = 0x18, .a = 0xff },
    .{ .r = 0x58, .g = 0xd8, .b = 0x54, .a = 0xff }, .{ .r = 0x58, .g = 0xf8, .b = 0x98, .a = 0xff },
    .{ .r = 0x00, .g = 0xe8, .b = 0xd8, .a = 0xff }, .{ .r = 0x78, .g = 0x78, .b = 0x78, .a = 0xff },
    .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff }, .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff },
    .{ .r = 0xfc, .g = 0xfc, .b = 0xfc, .a = 0xff }, .{ .r = 0xa4, .g = 0xe4, .b = 0xfc, .a = 0xff },
    .{ .r = 0xb8, .g = 0xb8, .b = 0xf8, .a = 0xff }, .{ .r = 0xd8, .g = 0xb8, .b = 0xf8, .a = 0xff },
    .{ .r = 0xf8, .g = 0xb8, .b = 0xf8, .a = 0xff }, .{ .r = 0xf8, .g = 0xa4, .b = 0xc0, .a = 0xff },
    .{ .r = 0xf0, .g = 0xd0, .b = 0xb0, .a = 0xff }, .{ .r = 0xfc, .g = 0xe0, .b = 0xa8, .a = 0xff },
    .{ .r = 0xf8, .g = 0xd8, .b = 0x78, .a = 0xff }, .{ .r = 0xd8, .g = 0xf8, .b = 0x78, .a = 0xff },
    .{ .r = 0xb8, .g = 0xf8, .b = 0xb8, .a = 0xff }, .{ .r = 0xb8, .g = 0xf8, .b = 0xd8, .a = 0xff },
    .{ .r = 0x00, .g = 0xfc, .b = 0xfc, .a = 0xff }, .{ .r = 0xf8, .g = 0xd8, .b = 0xf8, .a = 0xff },
    .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff }, .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff },
};

// APU lookup tables
const length_table = [32]u8{
    10, 254, 20, 2,  40, 4,  80, 6,  160, 8,  60, 10, 14, 12, 26, 14,
    12, 16,  24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30,
};

const duty_table = [4][8]u8{
    .{ 0, 1, 0, 0, 0, 0, 0, 0 },
    .{ 0, 1, 1, 0, 0, 0, 0, 0 },
    .{ 0, 1, 1, 1, 1, 0, 0, 0 },
    .{ 1, 0, 0, 1, 1, 1, 1, 1 },
};

const triangle_table = [32]u8{
    15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5,  4,  3,  2,  1,  0,
    0,  1,  2,  3,  4,  5,  6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
};

const noise_period_table = [16]u16{
    4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068,
};

const dmc_rate_table = [16]u16{
    428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54,
};

// ================================
// Public API Functions
// ================================

pub fn make() ?*Agnes {
    const allocator = std.heap.c_allocator;
    const agnes = allocator.create(Agnes) catch return null;
    @memset(std.mem.asBytes(agnes), 0);
    @memset(&agnes.ram, 0xff);
    return agnes;
}

pub fn destroy(agnes: *Agnes) void {
    const allocator = std.heap.c_allocator;
    // Free ROM data if it was allocated
    if (agnes.gamepack.data) |data| {
        const header: *const InesHeader = @ptrCast(@alignCast(data));
        var prg_rom_offset: usize = @sizeOf(InesHeader);
        const has_trainer = getBit(header.flags_6, 2) != 0;
        if (has_trainer) {
            prg_rom_offset += 512;
        }
        const prg_rom_size: usize = @as(usize, header.prg_rom_banks_count) * (16 * 1024);
        const chr_rom_size: usize = @as(usize, header.chr_rom_banks_count) * (8 * 1024);
        const total_size = prg_rom_offset + prg_rom_size + chr_rom_size;

        const data_slice: []u8 = @constCast(data[0..total_size]);
        allocator.free(data_slice);
    }
    allocator.destroy(agnes);
}

fn getInputByte(input: *const Input) u8 {
    var res: u8 = 0;
    res |= @as(u8, @intFromBool(input.a)) << 0;
    res |= @as(u8, @intFromBool(input.b)) << 1;
    res |= @as(u8, @intFromBool(input.select)) << 2;
    res |= @as(u8, @intFromBool(input.start)) << 3;
    res |= @as(u8, @intFromBool(input.up)) << 4;
    res |= @as(u8, @intFromBool(input.down)) << 5;
    res |= @as(u8, @intFromBool(input.left)) << 6;
    res |= @as(u8, @intFromBool(input.right)) << 7;
    return res;
}

pub fn setInput(agnes: *Agnes, input_1: ?*const Input, input_2: ?*const Input) void {
    if (input_1) |inp| {
        agnes.controllers[0].state = getInputByte(inp);
    }
    if (input_2) |inp| {
        agnes.controllers[1].state = getInputByte(inp);
    }
}

pub fn loadInesData(agnes: *Agnes, data: *anyopaque, data_size: usize) bool {
    if (data_size < @sizeOf(InesHeader)) {
        return false;
    }

    const header: *InesHeader = @ptrCast(@alignCast(data));
    if (!std.mem.eql(u8, &header.magic, "NES\x1a")) {
        return false;
    }

    var prg_rom_offset: u32 = @sizeOf(InesHeader);
    const has_trainer = getBit(header.flags_6, 2) != 0;
    if (has_trainer) {
        prg_rom_offset += 512;
    }

    agnes.gamepack.chr_rom_banks_count = @intCast(header.chr_rom_banks_count);
    agnes.gamepack.prg_rom_banks_count = @intCast(header.prg_rom_banks_count);

    if (getBit(header.flags_6, 3) != 0) {
        agnes.mirroring_mode = .four_screen;
    } else {
        agnes.mirroring_mode = if (getBit(header.flags_6, 0) != 0) .vertical else .horizontal;
    }

    agnes.gamepack.mapper = ((header.flags_6 & 0xf0) >> 4) | (header.flags_7 & 0xf0);
    const prg_rom_size: u32 = @as(u32, @intCast(header.prg_rom_banks_count)) * (16 * 1024);
    const chr_rom_size: u32 = @as(u32, @intCast(header.chr_rom_banks_count)) * (8 * 1024);
    const chr_rom_offset = prg_rom_offset + prg_rom_size;

    if ((chr_rom_offset + chr_rom_size) > data_size) {
        return false;
    }

    agnes.gamepack.data = @ptrCast(data);
    agnes.gamepack.prg_rom_offset = prg_rom_offset;
    agnes.gamepack.chr_rom_offset = chr_rom_offset;

    if (!mapperInit(agnes)) {
        return false;
    }

    cpuInit(&agnes.cpu, agnes);
    ppuInit(&agnes.ppu, agnes);
    apuInit(&agnes.apu, agnes);

    return true;
}

pub fn tick(agnes: *Agnes, out_new_frame: *bool) bool {
    const cpu_cycles = cpuTick(&agnes.cpu);
    if (cpu_cycles == 0) {
        return false;
    }

    const ppu_cycles = cpu_cycles * 3;
    var i: i32 = 0;
    while (i < ppu_cycles) : (i += 1) {
        ppuTick(&agnes.ppu, out_new_frame);
    }

    // APU runs at CPU speed
    i = 0;
    while (i < cpu_cycles) : (i += 1) {
        apuTick(&agnes.apu);
    }

    return true;
}

pub fn nextFrame(agnes: *Agnes) bool {
    while (true) {
        var new_frame = false;
        const ok = tick(agnes, &new_frame);
        if (!ok) {
            return false;
        }
        if (new_frame) {
            break;
        }
    }
    return true;
}

pub fn getScreenPixel(agnes: *const Agnes, x: i32, y: i32) Color {
    const ix: usize = @intCast((y * SCREEN_WIDTH) + x);
    const color_ix = agnes.ppu.screen_buffer[ix];
    return colors[color_ix & 0x3f];
}

pub fn getAudioSample(agnes: *Agnes) f32 {
    return apuGetSample(&agnes.apu);
}

pub fn getAudioSamplesAvailable(agnes: *Agnes) u32 {
    return apuSamplesAvailable(&agnes.apu);
}

pub fn stateSize() usize {
    return @sizeOf(AgnesState);
}

pub fn dumpState(agnes: *const Agnes, out_res: *AgnesState) void {
    out_res.agnes = agnes.*;
    out_res.agnes.gamepack.data = null;
    out_res.agnes.cpu.agnes = undefined;
    out_res.agnes.ppu.agnes = undefined;
    out_res.agnes.apu.agnes = undefined;
    switch (out_res.agnes.gamepack.mapper) {
        0 => out_res.agnes.mapper.m0.agnes = undefined,
        1 => out_res.agnes.mapper.m1.agnes = undefined,
        2 => out_res.agnes.mapper.m2.agnes = undefined,
        4 => out_res.agnes.mapper.m4.agnes = undefined,
        else => {},
    }
}

pub fn restoreState(agnes: *Agnes, state: *const AgnesState) bool {
    const gamepack_data = agnes.gamepack.data;
    agnes.* = state.agnes;
    agnes.gamepack.data = gamepack_data;
    agnes.cpu.agnes = agnes;
    agnes.ppu.agnes = agnes;
    agnes.apu.agnes = agnes;
    switch (agnes.gamepack.mapper) {
        0 => agnes.mapper.m0.agnes = agnes,
        1 => agnes.mapper.m1.agnes = agnes,
        2 => agnes.mapper.m2.agnes = agnes,
        4 => agnes.mapper.m4.agnes = agnes,
        else => {},
    }
    return true;
}

pub fn loadInesDataFromPath(agnes: *Agnes, filename: [*:0]const u8) bool {
    const allocator = std.heap.c_allocator;

    const file = std.fs.cwd().openFileZ(filename, .{}) catch return false;
    defer file.close();

    const file_size = file.getEndPos() catch return false;
    const file_contents = allocator.alloc(u8, file_size) catch return false;
    // DO NOT free file_contents here! agnes.gamepack.data will point to it
    // It should be freed in agnes_destroy

    _ = file.readAll(file_contents) catch return false;

    return loadInesData(agnes, file_contents.ptr, file_size);
}

// ================================
// CPU Implementation
// ================================

fn cpuInit(cpu: *Cpu, agnes: *Agnes) void {
    @memset(std.mem.asBytes(cpu), 0);
    cpu.agnes = agnes;
    cpu.pc = cpuRead16(cpu, 0xfffc); // RESET vector
    cpu.sp = 0xfd;
    cpuRestoreFlags(cpu, 0x24);
}

fn cpuTick(cpu: *Cpu) i32 {
    if (cpu.stall > 0) {
        cpu.stall -= 1;
        return 1;
    }

    var cycles: i32 = 0;

    if (cpu.interrupt != .none) {
        cycles += handleInterrupt(cpu);
    }

    const opcode = cpuRead8(cpu, cpu.pc);
    const instruction = instructionGet(opcode);
    if (instruction.operation == null) {
        return 0;
    }

    const ins_size = instructionGetSize(instruction.mode);
    var page_crossed = false;
    const addr = getInstructionOperand(cpu, instruction.mode, &page_crossed);

    cpu.pc +%= ins_size;

    cycles += @intCast(instruction.cycles);
    cycles += instruction.operation.?(cpu, addr, instruction.mode);

    if (page_crossed and instruction.page_cross_cycle) {
        cycles += 1;
    }

    cpu.cycles += @intCast(cycles);

    return cycles;
}

pub fn cpuUpdateZnFlags(cpu: *Cpu, val: u8) void {
    cpu.flag_zero = if (val == 0) 1 else 0;
    cpu.flag_negative = getBit(val, 7);
}

pub fn cpuStackPush8(cpu: *Cpu, val: u8) void {
    const addr: u16 = 0x0100 + @as(u16, cpu.sp);
    cpuWrite8(cpu, addr, val);
    cpu.sp -%= 1;
}

pub fn cpuStackPush16(cpu: *Cpu, val: u16) void {
    cpuStackPush8(cpu, @truncate(val >> 8));
    cpuStackPush8(cpu, @truncate(val));
}

pub fn cpuStackPop8(cpu: *Cpu) u8 {
    cpu.sp +%= 1;
    const addr: u16 = 0x0100 + @as(u16, cpu.sp);
    return cpuRead8(cpu, addr);
}

pub fn cpuStackPop16(cpu: *Cpu) u16 {
    const lo: u16 = cpuStackPop8(cpu);
    const hi: u16 = cpuStackPop8(cpu);
    return (hi << 8) | lo;
}

pub fn cpuGetFlags(cpu: *const Cpu) u8 {
    var res: u8 = 0;
    res |= cpu.flag_carry << 0;
    res |= cpu.flag_zero << 1;
    res |= cpu.flag_dis_interrupt << 2;
    res |= cpu.flag_decimal << 3;
    res |= cpu.flag_overflow << 6;
    res |= cpu.flag_negative << 7;
    return res;
}

pub fn cpuRestoreFlags(cpu: *Cpu, flags: u8) void {
    cpu.flag_carry = getBit(flags, 0);
    cpu.flag_zero = getBit(flags, 1);
    cpu.flag_dis_interrupt = getBit(flags, 2);
    cpu.flag_decimal = getBit(flags, 3);
    cpu.flag_overflow = getBit(flags, 6);
    cpu.flag_negative = getBit(flags, 7);
}

fn cpuTriggerNmi(cpu: *Cpu) void {
    cpu.interrupt = .nmi;
}

fn cpuTriggerIrq(cpu: *Cpu) void {
    if (cpu.flag_dis_interrupt == 0) {
        cpu.interrupt = .irq;
    }
}

fn cpuSetDmaStall(cpu: *Cpu) void {
    cpu.stall = if ((cpu.cycles & 0x1) != 0) 514 else 513;
}

pub fn cpuWrite8(cpu: *Cpu, addr: u16, val: u8) void {
    const agnes = cpu.agnes;

    if (addr < 0x2000) {
        agnes.ram[addr & 0x7ff] = val;
    } else if (addr < 0x4000) {
        ppuWriteRegister(&agnes.ppu, 0x2000 | (addr & 0x7), val);
    } else if (addr == 0x4014) {
        ppuWriteRegister(&agnes.ppu, 0x4014, val);
    } else if (addr == 0x4016) {
        agnes.controllers_latch = (val & 0x1) != 0;
        if (agnes.controllers_latch) {
            agnes.controllers[0].shift = agnes.controllers[0].state;
            agnes.controllers[1].shift = agnes.controllers[1].state;
        }
    } else if (addr >= 0x4000 and addr <= 0x4013) {
        apuWriteRegister(&agnes.apu, addr, val);
    } else if (addr == 0x4015 or addr == 0x4017) {
        apuWriteRegister(&agnes.apu, addr, val);
    } else if (addr < 0x4020) {
        // disabled
    } else {
        mapperWrite(agnes, addr, val);
    }
}

pub fn cpuRead8(cpu: *Cpu, addr: u16) u8 {
    const agnes = cpu.agnes;

    var res: u8 = 0;
    if (addr >= 0x4020) {
        res = mapperRead(agnes, addr);
    } else if (addr < 0x2000) {
        res = agnes.ram[addr & 0x7ff];
    } else if (addr < 0x4000) {
        res = ppuReadRegister(&agnes.ppu, 0x2000 | (addr & 0x7));
    } else if (addr == 0x4015) {
        res = apuReadRegister(&agnes.apu, addr);
    } else if (addr < 0x4016) {
        // other apu registers (mostly write-only)
    } else if (addr < 0x4018) {
        const controller: usize = @intCast(addr & 0x1);
        if (agnes.controllers_latch) {
            agnes.controllers[controller].shift = agnes.controllers[controller].state;
        }
        res = agnes.controllers[controller].shift & 0x1;
        agnes.controllers[controller].shift >>= 1;
    }
    return res;
}

pub fn cpuRead16(cpu: *Cpu, addr: u16) u16 {
    const lo: u16 = cpuRead8(cpu, addr);
    const hi: u16 = cpuRead8(cpu, addr +% 1);
    return (hi << 8) | lo;
}

fn cpuRead16IndirectBug(cpu: *Cpu, addr: u16) u16 {
    const lo: u16 = cpuRead8(cpu, addr);
    const hi: u16 = cpuRead8(cpu, (addr & 0xff00) | ((addr +% 1) & 0x00ff));
    return (hi << 8) | lo;
}

fn getInstructionOperand(cpu: *Cpu, mode: AddrMode, out_pages_differ: *bool) u16 {
    out_pages_differ.* = false;
    return switch (mode) {
        .absolute => cpuRead16(cpu, cpu.pc +% 1),
        .absolute_x => {
            const a = cpuRead16(cpu, cpu.pc +% 1);
            const res = a +% cpu.x;
            out_pages_differ.* = checkPagesDiffer(a, res);
            return res;
        },
        .absolute_y => {
            const a = cpuRead16(cpu, cpu.pc +% 1);
            const res = a +% cpu.y;
            out_pages_differ.* = checkPagesDiffer(a, res);
            return res;
        },
        .immediate => cpu.pc +% 1,
        .indirect => {
            const a = cpuRead16(cpu, cpu.pc +% 1);
            return cpuRead16IndirectBug(cpu, a);
        },
        .indirect_x => {
            const a = cpuRead8(cpu, cpu.pc +% 1);
            return cpuRead16IndirectBug(cpu, (a +% cpu.x) & 0xff);
        },
        .indirect_y => {
            const arg = cpuRead8(cpu, cpu.pc +% 1);
            const addr2 = cpuRead16IndirectBug(cpu, arg);
            const res = addr2 +% cpu.y;
            out_pages_differ.* = checkPagesDiffer(addr2, res);
            return res;
        },
        .zero_page => cpuRead8(cpu, cpu.pc +% 1),
        .zero_page_x => (cpuRead8(cpu, cpu.pc +% 1) +% cpu.x) & 0xff,
        .zero_page_y => (cpuRead8(cpu, cpu.pc +% 1) +% cpu.y) & 0xff,
        .relative => {
            const a = cpuRead8(cpu, cpu.pc +% 1);
            if (a < 0x80) {
                return cpu.pc +% a +% 2;
            } else {
                return cpu.pc +% a +% 2 -% 0x100;
            }
        },
        else => 0,
    };
}

fn handleInterrupt(cpu: *Cpu) i32 {
    const addr: u16 = if (cpu.interrupt == .nmi) 0xfffa else if (cpu.interrupt == .irq) 0xfffe else return 0;

    cpu.interrupt = .none;
    cpuStackPush16(cpu, cpu.pc);
    const flags = cpuGetFlags(cpu);
    cpuStackPush8(cpu, flags | 0x20);
    cpu.pc = cpuRead16(cpu, addr);
    cpu.flag_dis_interrupt = 1;
    return 7;
}

fn checkPagesDiffer(a: u16, b: u16) bool {
    return (0xff00 & a) != (0xff00 & b);
}

// ================================
// PPU Implementation
// ================================

fn ppuInit(ppu: *Ppu, agnes: *Agnes) void {
    @memset(std.mem.asBytes(ppu), 0);
    ppu.agnes = agnes;
    ppuWriteRegister(ppu, 0x2000, 0);
    ppuWriteRegister(ppu, 0x2001, 0);
}

fn ppuTick(ppu: *Ppu, out_new_frame: *bool) void {
    const rendering_enabled = ppu.masks.show_background or ppu.masks.show_sprites;

    // https://wiki.nesdev.com/w/index.php/PPU_frame_timing#Even.2FOdd_Frames
    if (rendering_enabled and ppu.is_odd_frame and ppu.dot == 339 and ppu.scanline == 261) {
        ppu.dot = 0;
        ppu.scanline = 0;
        ppu.is_odd_frame = !ppu.is_odd_frame;
    } else {
        ppu.dot += 1;

        if (ppu.dot > 340) {
            ppu.dot = 0;
            ppu.scanline += 1;
        }

        if (ppu.scanline > 261) {
            ppu.scanline = 0;
            ppu.is_odd_frame = !ppu.is_odd_frame;
        }
    }

    if (ppu.dot == 0) {
        return;
    }

    const scanline_visible = ppu.scanline >= 0 and ppu.scanline < 240;
    const scanline_pre = ppu.scanline == 261;
    const scanline_post = ppu.scanline == 241;

    if (rendering_enabled and (scanline_visible or scanline_pre)) {
        scanlineVisiblePre(ppu, out_new_frame);
    }

    if (ppu.dot == 1) {
        if (scanline_pre) {
            ppu.status.sprite_overflow = false;
            ppu.status.sprite_zero_hit = false;
            ppu.status.in_vblank = false;
        } else if (scanline_post) {
            ppu.status.in_vblank = true;
            out_new_frame.* = true;
            if (ppu.ctrl.nmi_enabled) {
                cpuTriggerNmi(&ppu.agnes.cpu);
            }
        }
    }
}

fn scanlineVisiblePre(ppu: *Ppu, out_new_frame: *bool) void {
    _ = out_new_frame;
    const scanline_visible = ppu.scanline >= 0 and ppu.scanline < 240;
    const scanline_pre = ppu.scanline == 261;
    const dot_visible = ppu.dot > 0 and ppu.dot <= 256;
    const dot_fetch = ppu.dot <= 256 or (ppu.dot >= 321 and ppu.dot < 337);

    if (scanline_visible and dot_visible) {
        emitPixel(ppu);
    }

    if (dot_fetch) {
        ppu.bg_lo_shift <<= 1;
        ppu.bg_hi_shift <<= 1;
        ppu.at_shift = (ppu.at_shift << 2) | (ppu.at_latch & 0x3);

        switch (ppu.dot & 0x7) {
            1 => {
                const addr: u16 = 0x2000 | (ppu.regs.v & 0x0fff);
                ppu.nt = ppuRead8(ppu, addr);
            },
            3 => {
                const v = ppu.regs.v;
                const addr: u16 = 0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07);
                ppu.at = ppuRead8(ppu, addr);
                if ((ppu.regs.v & 0x40) != 0) {
                    ppu.at = ppu.at >> 4;
                }
                if ((ppu.regs.v & 0x02) != 0) {
                    ppu.at = ppu.at >> 2;
                }
            },
            5 => {
                const fine_y: u8 = @truncate((ppu.regs.v) >> 12 & 0x7);
                const addr = ppu.ctrl.bg_table_addr + (@as(u16, ppu.nt) << 4) + fine_y;
                ppu.bg_lo = ppuRead8(ppu, addr);
            },
            7 => {
                const fine_y: u8 = @truncate((ppu.regs.v) >> 12 & 0x7);
                const addr = ppu.ctrl.bg_table_addr + (@as(u16, ppu.nt) << 4) + fine_y + 8;
                ppu.bg_hi = ppuRead8(ppu, addr);
            },
            0 => {
                ppu.bg_lo_shift = (ppu.bg_lo_shift & 0xff00) | ppu.bg_lo;
                ppu.bg_hi_shift = (ppu.bg_hi_shift & 0xff00) | ppu.bg_hi;
                ppu.at_latch = ppu.at & 0x3;

                if (ppu.dot == 256) {
                    incVertV(ppu);
                } else {
                    incHoriV(ppu);
                }
            },
            else => {},
        }
    }

    if (ppu.dot == 257) {
        ppu.regs.v = (ppu.regs.v & 0xfbe0) | (ppu.regs.t & ~@as(u16, 0xfbe0));

        if (scanline_visible) {
            evalSprites(ppu);
        } else {
            ppu.sprite_ixs_count = 0;
        }
    }

    if (scanline_pre and ppu.dot >= 280 and ppu.dot <= 304) {
        ppu.regs.v = (ppu.regs.v & 0x841f) | (ppu.regs.t & ~@as(u16, 0x841f));
    }

    if (ppu.masks.show_background and ppu.masks.show_sprites) {
        if ((ppu.ctrl.bg_table_addr == 0x0000 and ppu.dot == 270) or
            (ppu.ctrl.bg_table_addr == 0x1000 and ppu.dot == 324))
        {
            mapperPa12RisingEdge(ppu.agnes);
        }
    }
}

inline fn getCoarseX(v: u16) u16 {
    return v & 0x1f;
}

inline fn setCoarseX(v: *u16, cx: u16) void {
    v.* = (v.* & ~@as(u16, 0x1f)) | (cx & 0x1f);
}

inline fn getCoarseY(v: u16) u16 {
    return (v >> 5) & 0x1f;
}

inline fn setCoarseY(v: *u16, cy: u16) void {
    v.* = (v.* & ~@as(u16, 0x3e0)) | ((cy & 0x1f) << 5);
}

inline fn getFineY(v: u16) u16 {
    return v >> 12;
}

inline fn setFineY(v: *u16, fy: u16) void {
    v.* = (v.* & ~@as(u16, 0x7000)) | ((fy & 0x7) << 12);
}

fn incHoriV(ppu: *Ppu) void {
    const cx = getCoarseX(ppu.regs.v);
    if (cx == 31) {
        setCoarseX(&ppu.regs.v, 0);
        ppu.regs.v ^= 0x0400;
    } else {
        setCoarseX(&ppu.regs.v, cx + 1);
    }
}

fn incVertV(ppu: *Ppu) void {
    const fy = getFineY(ppu.regs.v);
    if (fy < 7) {
        setFineY(&ppu.regs.v, fy + 1);
    } else {
        setFineY(&ppu.regs.v, 0);
        const cy = getCoarseY(ppu.regs.v);
        if (cy == 29) {
            setCoarseY(&ppu.regs.v, 0);
            ppu.regs.v ^= 0x0800;
        } else if (cy == 31) {
            setCoarseY(&ppu.regs.v, 0);
        } else {
            setCoarseY(&ppu.regs.v, cy + 1);
        }
    }
}

fn evalSprites(ppu: *Ppu) void {
    ppu.sprite_ixs_count = 0;
    const sprites: [*]const Sprite = @ptrCast(&ppu.oam_data);
    const sprite_height: i32 = if (ppu.ctrl.use_8x16_sprites) 16 else 8;

    var i: i32 = 0;
    while (i < 64) : (i += 1) {
        const sprite = &sprites[@intCast(i)];

        if (sprite.y_pos > 0xef or sprite.x_pos > 0xff) {
            continue;
        }

        const s_y = ppu.scanline - @as(i32, @intCast(sprite.y_pos));
        if (s_y < 0 or s_y >= sprite_height) {
            continue;
        }

        if (ppu.sprite_ixs_count < 8) {
            ppu.sprites[@intCast(ppu.sprite_ixs_count)] = sprite.*;
            ppu.sprite_ixs[@intCast(ppu.sprite_ixs_count)] = i;
            ppu.sprite_ixs_count += 1;
        } else {
            ppu.status.sprite_overflow = true;
            break;
        }
    }
}

fn emitPixel(ppu: *Ppu) void {
    const x = ppu.dot - 1;
    const y = ppu.scanline;

    if (x < 8 and !ppu.masks.show_leftmost_bg and !ppu.masks.show_leftmost_sprites) {
        setPixelColorIx(ppu, x, y, 63);
        return;
    }

    const bg_color_addr = getBgColorAddr(ppu);

    var sprite_ix: i32 = -1;
    var behind_bg = false;
    const sp_color_addr = getSpriteColorAddr(ppu, &sprite_ix, &behind_bg);

    var color_addr: u16 = 0x3f00;
    if (bg_color_addr != 0 and sp_color_addr != 0) {
        if (sprite_ix == 0 and x != 255) {
            ppu.status.sprite_zero_hit = true;
        }
        color_addr = if (behind_bg) bg_color_addr else sp_color_addr;
    } else if (bg_color_addr != 0 and sp_color_addr == 0) {
        color_addr = bg_color_addr;
    } else if (bg_color_addr == 0 and sp_color_addr != 0) {
        color_addr = sp_color_addr;
    }

    const output_color_ix = ppuRead8(ppu, color_addr);
    setPixelColorIx(ppu, x, y, output_color_ix);
}

fn getBgColorAddr(ppu: *Ppu) u16 {
    if (!ppu.masks.show_background or (!ppu.masks.show_leftmost_bg and ppu.dot < 9)) {
        return 0;
    }

    const hi_bit = getBit(ppu.bg_hi_shift, @as(u8, 15 - ppu.regs.x)) != 0;
    const lo_bit = getBit(ppu.bg_lo_shift, @as(u8, 15 - ppu.regs.x)) != 0;

    if (!lo_bit and !hi_bit) {
        return 0;
    }

    const palette: u8 = @truncate((ppu.at_shift >> @intCast(14 - (ppu.regs.x << 1))) & 0x3);
    const palette_ix: u8 = (@as(u8, @intFromBool(hi_bit)) << 1) | @intFromBool(lo_bit);
    const color_address: u16 = 0x3f00 | (@as(u16, palette) << 2) | palette_ix;
    return color_address;
}

fn getSpriteColorAddr(ppu: *Ppu, out_sprite_ix: *i32, out_behind_bg: *bool) u16 {
    out_sprite_ix.* = -1;
    out_behind_bg.* = false;

    const x = ppu.dot - 1;
    const y = ppu.scanline;

    if (!ppu.masks.show_sprites or (!ppu.masks.show_leftmost_sprites and x < 8)) {
        return 0;
    }

    const sprite_height: i32 = if (ppu.ctrl.use_8x16_sprites) 16 else 8;
    var table = ppu.ctrl.sprite_table_addr;

    var i: i32 = 0;
    while (i < ppu.sprite_ixs_count) : (i += 1) {
        const sprite = &ppu.sprites[@intCast(i)];
        var s_x = x - @as(i32, @intCast(sprite.x_pos));
        if (s_x < 0 or s_x >= 8) {
            continue;
        }

        var s_y = y - @as(i32, @intCast(sprite.y_pos)) - 1;

        s_x = if (getBit(sprite.attrs, 6) != 0) 7 - s_x else s_x;
        s_y = if (getBit(sprite.attrs, 7) != 0) sprite_height - 1 - s_y else s_y;

        var tile_num = sprite.tile_num;
        if (ppu.ctrl.use_8x16_sprites) {
            table = if ((tile_num & 0x1) != 0) 0x1000 else 0x0000;
            tile_num &= 0xfe;
            if (s_y >= 8) {
                tile_num += 1;
                s_y -= 8;
            }
        }

        const offset = table + (@as(u16, tile_num) << 4) + @as(u16, @intCast(s_y));

        const lo_byte = ppuRead8(ppu, offset);
        const hi_byte = ppuRead8(ppu, offset + 8);

        if (lo_byte == 0 and hi_byte == 0) {
            continue;
        }

        const lo_bit = getBit(lo_byte, @as(u8, @intCast(7 - s_x))) != 0;
        const hi_bit = getBit(hi_byte, @as(u8, @intCast(7 - s_x))) != 0;

        if (lo_bit or hi_bit) {
            out_sprite_ix.* = ppu.sprite_ixs[@intCast(i)];
            if (getBit(sprite.attrs, 5) != 0) {
                out_behind_bg.* = true;
            }
            const palette_ix: u8 = (@as(u8, @intFromBool(hi_bit)) << 1) | @intFromBool(lo_bit);
            const color_address: u16 = 0x3f10 | (@as(u16, sprite.attrs & 0x3) << 2) | palette_ix;
            return color_address;
        }
    }
    return 0;
}

fn ppuReadRegister(ppu: *Ppu, addr: u16) u8 {
    switch (addr) {
        0x2002 => {
            var res: u8 = 0;
            res |= ppu.last_reg_write & 0x1f;
            res |= @as(u8, @intFromBool(ppu.status.sprite_overflow)) << 5;
            res |= @as(u8, @intFromBool(ppu.status.sprite_zero_hit)) << 6;
            res |= @as(u8, @intFromBool(ppu.status.in_vblank)) << 7;
            ppu.status.in_vblank = false;
            ppu.regs.w = 0;
            return res;
        },
        0x2004 => {
            return ppu.oam_data[ppu.oam_address];
        },
        0x2007 => {
            var res: u8 = 0;
            if (ppu.regs.v < 0x3f00) {
                res = ppu.ppudata_buffer;
                ppu.ppudata_buffer = ppuRead8(ppu, ppu.regs.v);
            } else {
                res = ppuRead8(ppu, ppu.regs.v);
                ppu.ppudata_buffer = ppuRead8(ppu, ppu.regs.v -% 0x1000);
            }
            ppu.regs.v +%= ppu.ctrl.addr_increment;
            return res;
        },
        else => return 0,
    }
}

fn ppuWriteRegister(ppu: *Ppu, addr: u16, val: u8) void {
    ppu.last_reg_write = val;
    switch (addr) {
        0x2000 => {
            ppu.ctrl.addr_increment = if (getBit(val, 2) != 0) 32 else 1;
            ppu.ctrl.sprite_table_addr = if (getBit(val, 3) != 0) 0x1000 else 0x0000;
            ppu.ctrl.bg_table_addr = if (getBit(val, 4) != 0) 0x1000 else 0x0000;
            ppu.ctrl.use_8x16_sprites = getBit(val, 5) != 0;
            ppu.ctrl.nmi_enabled = getBit(val, 7) != 0;
            ppu.regs.t = (ppu.regs.t & 0xf3ff) | ((@as(u16, val) & 0x03) << 10);
        },
        0x2001 => {
            ppu.masks.show_leftmost_bg = getBit(val, 1) != 0;
            ppu.masks.show_leftmost_sprites = getBit(val, 2) != 0;
            ppu.masks.show_background = getBit(val, 3) != 0;
            ppu.masks.show_sprites = getBit(val, 4) != 0;
        },
        0x2003 => {
            ppu.oam_address = val;
        },
        0x2004 => {
            ppu.oam_data[ppu.oam_address] = val;
            ppu.oam_address +%= 1;
        },
        0x2005 => {
            if (ppu.regs.w != 0) {
                ppu.regs.t = (ppu.regs.t & 0x8fff) | ((@as(u16, val) & 0x7) << 12);
                ppu.regs.t = (ppu.regs.t & 0xfc1f) | (@as(u16, val >> 3) << 5);
                ppu.regs.w = 0;
            } else {
                ppu.regs.t = (ppu.regs.t & 0xffe0) | (val >> 3);
                ppu.regs.x = val & 0x7;
                ppu.regs.w = 1;
            }
        },
        0x2006 => {
            if (ppu.regs.w != 0) {
                ppu.regs.t = (ppu.regs.t & 0xff00) | val;
                ppu.regs.v = ppu.regs.t;
                ppu.regs.w = 0;
            } else {
                ppu.regs.t = (ppu.regs.t & 0xc0ff) | ((@as(u16, val) & 0x3f) << 8);
                ppu.regs.t = ppu.regs.t & 0xbfff;
                ppu.regs.w = 1;
            }
        },
        0x2007 => {
            ppuWrite8(ppu, ppu.regs.v, val);
            ppu.regs.v +%= ppu.ctrl.addr_increment;
        },
        0x4014 => {
            var dma_addr: u16 = @as(u16, val) << 8;
            var i: u32 = 0;
            while (i < 256) : (i += 1) {
                ppu.oam_data[ppu.oam_address] = cpuRead8(&ppu.agnes.cpu, dma_addr);
                ppu.oam_address +%= 1;
                dma_addr +%= 1;
            }
            cpuSetDmaStall(&ppu.agnes.cpu);
        },
        else => {},
    }
}

fn setPixelColorIx(ppu: *Ppu, x: i32, y: i32, color_ix: u8) void {
    const ix: usize = @intCast((y * SCREEN_WIDTH) + x);
    ppu.screen_buffer[ix] = color_ix;
}

fn ppuRead8(ppu: *Ppu, addr: u16) u8 {
    const a = addr & 0x3fff;
    var res: u8 = 0;
    if (a >= 0x3f00) {
        const palette_ix = palette_addr_map[a & 0x1f];
        res = ppu.palette[palette_ix];
    } else if (a < 0x2000) {
        res = mapperRead(ppu.agnes, a);
    } else {
        const mirrored_addr = mirrorAddress(ppu, a);
        res = ppu.nametables[mirrored_addr];
    }
    return res;
}

fn ppuWrite8(ppu: *Ppu, addr: u16, val: u8) void {
    const a = addr & 0x3fff;
    if (a >= 0x3f00) {
        const palette_ix = palette_addr_map[a & 0x1f];
        ppu.palette[palette_ix] = val;
    } else if (a < 0x2000) {
        mapperWrite(ppu.agnes, a, val);
    } else {
        const mirrored_addr = mirrorAddress(ppu, a);
        ppu.nametables[mirrored_addr] = val;
    }
}

fn mirrorAddress(ppu: *Ppu, addr: u16) u16 {
    return switch (ppu.agnes.mirroring_mode) {
        .horizontal => ((addr >> 1) & 0x400) | (addr & 0x3ff),
        .vertical => addr & 0x07ff,
        .single_lower => addr & 0x3ff,
        .single_upper => 0x400 | (addr & 0x3ff),
        .four_screen => addr -% 0x2000,
        else => 0,
    };
}

// ================================
// APU Implementation - Complete NES Audio Processing Unit
// ================================

// Lookup tables
const LENGTH_TABLE = [32]u8{
    10, 254, 20, 2,  40, 4,  80, 6,  160, 8,  60, 10, 14, 12, 26, 14,
    12, 16,  24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30,
};

const DUTY_TABLE = [4][8]u8{
    .{ 0, 1, 0, 0, 0, 0, 0, 0 },
    .{ 0, 1, 1, 0, 0, 0, 0, 0 },
    .{ 0, 1, 1, 1, 1, 0, 0, 0 },
    .{ 1, 0, 0, 1, 1, 1, 1, 1 },
};

const TRIANGLE_TABLE = [32]u8{
    15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5,  4,  3,  2,  1,  0,
    0,  1,  2,  3,  4,  5,  6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
};

const NOISE_PERIOD_TABLE = [16]u16{
    4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068,
};

const DMC_RATE_TABLE = [16]u16{
    428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54,
};

fn apuInit(apu: *Apu, agnes: *Agnes) void {
    @memset(std.mem.asBytes(apu), 0);
    apu.agnes = agnes;
    apu.noise.shift_register = 1;
    apu.frame_counter_mode = 0;
    apu.frame_interrupt_inhibit = false;
}

fn apuTick(apu: *Apu) void {
    apu.cycles += 1;

    // Tick frame counter
    apuTickFrameCounter(apu);

    // Tick timers at APU rate (CPU rate divided by 2)
    if (apu.cycles % 2 == 0) {
        pulseTickTimer(&apu.pulse1);
        pulseTickTimer(&apu.pulse2);
        noiseTickTimer(&apu.noise);
        dmcTickTimer(&apu.dmc, apu.agnes);
    }

    // Triangle runs at CPU rate
    triangleTickTimer(&apu.triangle);

    // Generate audio sample
    const CYCLES_PER_SAMPLE: f32 = 40.584;
    apu.sample_accumulator += 1.0;

    if (apu.sample_accumulator >= CYCLES_PER_SAMPLE) {
        apu.sample_accumulator -= CYCLES_PER_SAMPLE;

        const p1 = pulseOutput(&apu.pulse1);
        const p2 = pulseOutput(&apu.pulse2);
        const tri = triangleOutput(&apu.triangle);
        const noise = noiseOutput(&apu.noise);
        const dmc = dmcOutput(&apu.dmc);

        var sample = mixAudio(p1, p2, tri, noise, dmc);
        sample = applyHighpassFilter(apu, sample);
        sample = applyLowpassFilter(apu, sample);

        const next_write_pos = (apu.sample_write_pos + 1) % 4096;
        if (next_write_pos != apu.sample_read_pos) {
            apu.sample_buffer[apu.sample_write_pos] = sample;
            apu.sample_write_pos = next_write_pos;
        }
    }
}

fn apuReadRegister(apu: *Apu, addr: u16) u8 {
    if (addr == 0x4015) {
        var result: u8 = 0;
        if (apu.pulse1.length_counter > 0) result |= 0x01;
        if (apu.pulse2.length_counter > 0) result |= 0x02;
        if (apu.triangle.length_counter > 0) result |= 0x04;
        if (apu.noise.length_counter > 0) result |= 0x08;
        if (apu.dmc.bytes_remaining > 0) result |= 0x10;
        if (apu.frame_interrupt) result |= 0x40;
        if (apu.dmc.irq_enabled) result |= 0x80;

        apu.frame_interrupt = false;
        return result;
    }
    return 0;
}

fn apuWriteRegister(apu: *Apu, addr: u16, val: u8) void {
    switch (addr) {
        // Pulse 1
        0x4000 => {
            apu.pulse1.duty = (val >> 6) & 0x3;
            apu.pulse1.length_counter_halt = ((val >> 5) & 0x1) != 0;
            apu.pulse1.constant_volume = ((val >> 4) & 0x1) != 0;
            apu.pulse1.volume = val & 0xf;
        },
        0x4001 => {
            apu.pulse1.sweep_enabled = ((val >> 7) & 0x1) != 0;
            apu.pulse1.sweep_period = (val >> 4) & 0x7;
            apu.pulse1.sweep_negate = ((val >> 3) & 0x1) != 0;
            apu.pulse1.sweep_shift = val & 0x7;
            apu.pulse1.sweep_reload = true;
        },
        0x4002 => {
            apu.pulse1.timer_period = (apu.pulse1.timer_period & 0x700) | val;
        },
        0x4003 => {
            apu.pulse1.timer_period = (apu.pulse1.timer_period & 0xff) | ((@as(u16, val) & 0x7) << 8);
            apu.pulse1.length_counter = LENGTH_TABLE[val >> 3];
            apu.pulse1.duty_pos = 0;
            apu.pulse1.envelope_counter = 15;
        },

        // Pulse 2
        0x4004 => {
            apu.pulse2.duty = (val >> 6) & 0x3;
            apu.pulse2.length_counter_halt = ((val >> 5) & 0x1) != 0;
            apu.pulse2.constant_volume = ((val >> 4) & 0x1) != 0;
            apu.pulse2.volume = val & 0xf;
        },
        0x4005 => {
            apu.pulse2.sweep_enabled = ((val >> 7) & 0x1) != 0;
            apu.pulse2.sweep_period = (val >> 4) & 0x7;
            apu.pulse2.sweep_negate = ((val >> 3) & 0x1) != 0;
            apu.pulse2.sweep_shift = val & 0x7;
            apu.pulse2.sweep_reload = true;
        },
        0x4006 => {
            apu.pulse2.timer_period = (apu.pulse2.timer_period & 0x700) | val;
        },
        0x4007 => {
            apu.pulse2.timer_period = (apu.pulse2.timer_period & 0xff) | ((@as(u16, val) & 0x7) << 8);
            apu.pulse2.length_counter = LENGTH_TABLE[val >> 3];
            apu.pulse2.duty_pos = 0;
            apu.pulse2.envelope_counter = 15;
        },

        // Triangle
        0x4008 => {
            apu.triangle.length_counter_halt = ((val >> 7) & 0x1) != 0;
            apu.triangle.linear_counter_reload = val & 0x7f;
        },
        0x400A => {
            apu.triangle.timer_period = (apu.triangle.timer_period & 0x700) | val;
        },
        0x400B => {
            apu.triangle.timer_period = (apu.triangle.timer_period & 0xff) | ((@as(u16, val) & 0x7) << 8);
            apu.triangle.length_counter = LENGTH_TABLE[val >> 3];
            apu.triangle.linear_counter_reload_flag = true;
        },

        // Noise
        0x400C => {
            apu.noise.length_counter_halt = ((val >> 5) & 0x1) != 0;
            apu.noise.constant_volume = ((val >> 4) & 0x1) != 0;
            apu.noise.volume = val & 0xf;
        },
        0x400E => {
            apu.noise.mode = ((val >> 7) & 0x1) != 0;
            apu.noise.timer_period = NOISE_PERIOD_TABLE[val & 0xf];
        },
        0x400F => {
            apu.noise.length_counter = LENGTH_TABLE[val >> 3];
            apu.noise.envelope_counter = 15;
        },

        // DMC
        0x4010 => {
            apu.dmc.irq_enabled = ((val >> 7) & 0x1) != 0;
            apu.dmc.loop = ((val >> 6) & 0x1) != 0;
            apu.dmc.timer_period = DMC_RATE_TABLE[val & 0xf];
        },
        0x4011 => {
            apu.dmc.output_level = val & 0x7f;
        },
        0x4012 => {
            apu.dmc.sample_address = 0xC000 | (@as(u16, val) << 6);
        },
        0x4013 => {
            apu.dmc.sample_length = (@as(u16, val) << 4) | 1;
        },

        // Status
        0x4015 => {
            apu.pulse1.enabled = (val & 0x01) != 0;
            apu.pulse2.enabled = (val & 0x02) != 0;
            apu.triangle.enabled = (val & 0x04) != 0;
            apu.noise.enabled = (val & 0x08) != 0;
            apu.dmc.enabled = (val & 0x10) != 0;

            if (!apu.pulse1.enabled) apu.pulse1.length_counter = 0;
            if (!apu.pulse2.enabled) apu.pulse2.length_counter = 0;
            if (!apu.triangle.enabled) apu.triangle.length_counter = 0;
            if (!apu.noise.enabled) apu.noise.length_counter = 0;

            if (!apu.dmc.enabled) {
                apu.dmc.bytes_remaining = 0;
            } else if (apu.dmc.bytes_remaining == 0) {
                apu.dmc.current_address = apu.dmc.sample_address;
                apu.dmc.bytes_remaining = apu.dmc.sample_length;
            }
        },

        // Frame counter
        0x4017 => {
            apu.frame_counter_mode = (val >> 7) & 0x1;
            apu.frame_interrupt_inhibit = ((val >> 6) & 0x1) != 0;
            if (apu.frame_interrupt_inhibit) {
                apu.frame_interrupt = false;
            }
            apu.frame_counter = 0;
        },
        else => {},
    }
}

fn apuGetSample(apu: *Apu) f32 {
    if (apu.sample_read_pos != apu.sample_write_pos) {
        const sample = apu.sample_buffer[apu.sample_read_pos];
        apu.sample_read_pos = (apu.sample_read_pos + 1) % 4096;
        return sample;
    }
    return 0.0;
}

fn apuSamplesAvailable(apu: *Apu) u32 {
    if (apu.sample_write_pos >= apu.sample_read_pos) {
        return apu.sample_write_pos - apu.sample_read_pos;
    } else {
        return 4096 - apu.sample_read_pos + apu.sample_write_pos;
    }
}

// Pulse channel functions
fn pulseTickTimer(pulse: *PulseChannel) void {
    if (pulse.timer_value == 0) {
        pulse.timer_value = pulse.timer_period;
        pulse.duty_pos = (pulse.duty_pos + 1) % 8;
    } else {
        pulse.timer_value -= 1;
    }
}

fn pulseTickEnvelope(pulse: *PulseChannel) void {
    if (pulse.envelope_divider == 0) {
        pulse.envelope_divider = pulse.volume;
        if (pulse.envelope_counter > 0) {
            pulse.envelope_counter -= 1;
        } else if (pulse.length_counter_halt) {
            pulse.envelope_counter = 15;
        }
    } else {
        pulse.envelope_divider -= 1;
    }

    pulse.envelope_volume = if (pulse.constant_volume) pulse.volume else pulse.envelope_counter;
}

fn pulseTickSweep(pulse: *PulseChannel, is_pulse1: bool) void {
    if (pulse.sweep_divider == 0 and pulse.sweep_enabled) {
        const change = pulse.timer_period >> @intCast(pulse.sweep_shift);
        if (pulse.sweep_negate) {
            pulse.timer_period -%= change;
            if (is_pulse1) {
                pulse.timer_period -%= 1;
            }
        } else {
            pulse.timer_period +%= change;
        }
    }

    if (pulse.sweep_divider == 0 or pulse.sweep_reload) {
        pulse.sweep_divider = pulse.sweep_period;
        pulse.sweep_reload = false;
    } else {
        pulse.sweep_divider -= 1;
    }
}

fn pulseTickLengthCounter(pulse: *PulseChannel) void {
    if (!pulse.length_counter_halt and pulse.length_counter > 0) {
        pulse.length_counter -= 1;
    }
}

fn pulseOutput(pulse: *const PulseChannel) u8 {
    if (!pulse.enabled or pulse.length_counter == 0) {
        return 0;
    }

    if (pulse.timer_period < 8 or pulse.timer_period > 0x7FF) {
        return 0;
    }

    if (DUTY_TABLE[pulse.duty][pulse.duty_pos] == 0) {
        return 0;
    }

    return pulse.envelope_volume;
}

// Triangle channel functions
fn triangleTickTimer(tri: *TriangleChannel) void {
    if (tri.timer_value == 0) {
        tri.timer_value = tri.timer_period;
        if (tri.length_counter > 0 and tri.linear_counter > 0) {
            tri.sequence_pos = (tri.sequence_pos + 1) % 32;
        }
    } else {
        tri.timer_value -= 1;
    }
}

fn triangleTickLengthCounter(tri: *TriangleChannel) void {
    if (!tri.length_counter_halt and tri.length_counter > 0) {
        tri.length_counter -= 1;
    }
}

fn triangleTickLinearCounter(tri: *TriangleChannel) void {
    if (tri.linear_counter_reload_flag) {
        tri.linear_counter = tri.linear_counter_reload;
    } else if (tri.linear_counter > 0) {
        tri.linear_counter -= 1;
    }

    if (!tri.length_counter_halt) {
        tri.linear_counter_reload_flag = false;
    }
}

fn triangleOutput(tri: *const TriangleChannel) u8 {
    if (!tri.enabled or tri.length_counter == 0 or tri.linear_counter == 0) {
        return 0;
    }
    if (tri.timer_period < 2) {
        return 0;
    }
    return TRIANGLE_TABLE[tri.sequence_pos];
}

// Noise channel functions
fn noiseTickTimer(noise: *NoiseChannel) void {
    if (noise.timer_value == 0) {
        noise.timer_value = noise.timer_period;

        const feedback: u16 = if (noise.mode)
            ((noise.shift_register >> 6) ^ (noise.shift_register >> 0)) & 1
        else
            ((noise.shift_register >> 1) ^ (noise.shift_register >> 0)) & 1;

        noise.shift_register >>= 1;
        noise.shift_register |= feedback << 14;
    } else {
        noise.timer_value -= 1;
    }
}

fn noiseTickEnvelope(noise: *NoiseChannel) void {
    if (noise.envelope_divider == 0) {
        noise.envelope_divider = noise.volume;
        if (noise.envelope_counter > 0) {
            noise.envelope_counter -= 1;
        } else if (noise.length_counter_halt) {
            noise.envelope_counter = 15;
        }
    } else {
        noise.envelope_divider -= 1;
    }

    noise.envelope_volume = if (noise.constant_volume) noise.volume else noise.envelope_counter;
}

fn noiseTickLengthCounter(noise: *NoiseChannel) void {
    if (!noise.length_counter_halt and noise.length_counter > 0) {
        noise.length_counter -= 1;
    }
}

fn noiseOutput(noise: *const NoiseChannel) u8 {
    if (!noise.enabled or noise.length_counter == 0) {
        return 0;
    }

    if ((noise.shift_register & 1) == 1) {
        return 0;
    }

    return noise.envelope_volume;
}

// DMC channel functions
fn dmcTickTimer(dmc: *DmcChannel, agnes: *Agnes) void {
    if (dmc.timer_value == 0) {
        dmc.timer_value = dmc.timer_period;

        if (!dmc.silence) {
            if ((dmc.shift_register & 1) != 0) {
                if (dmc.output_level <= 125) {
                    dmc.output_level += 2;
                }
            } else {
                if (dmc.output_level >= 2) {
                    dmc.output_level -= 2;
                }
            }
        }

        dmc.shift_register >>= 1;
        dmc.bits_remaining -= 1;

        if (dmc.bits_remaining == 0) {
            dmc.bits_remaining = 8;
            if (dmc.sample_buffer_empty) {
                dmc.silence = true;
            } else {
                dmc.silence = false;
                dmc.shift_register = dmc.sample_buffer;
                dmc.sample_buffer_empty = true;
            }
        }

        if (dmc.sample_buffer_empty and dmc.bytes_remaining > 0) {
            dmc.sample_buffer = cpuRead8(&agnes.cpu, dmc.current_address);
            dmc.sample_buffer_empty = false;
            dmc.current_address +%= 1;
            if (dmc.current_address == 0) {
                dmc.current_address = 0x8000;
            }
            dmc.bytes_remaining -= 1;

            if (dmc.bytes_remaining == 0) {
                if (dmc.loop) {
                    dmc.current_address = dmc.sample_address;
                    dmc.bytes_remaining = dmc.sample_length;
                } else if (dmc.irq_enabled) {
                    cpuTriggerIrq(&agnes.cpu);
                }
            }
        }
    } else {
        dmc.timer_value -= 1;
    }
}

fn dmcOutput(dmc: *const DmcChannel) u8 {
    return dmc.output_level;
}

// Frame counter
fn apuTickFrameCounter(apu: *Apu) void {
    const step_cycles: u32 = 7457;

    if (apu.frame_counter_mode == 0) {
        // 4-step mode
        const step = (apu.cycles / step_cycles) % 4;
        const cycle_in_step = apu.cycles % step_cycles;

        if (cycle_in_step == 0) {
            pulseTickEnvelope(&apu.pulse1);
            pulseTickEnvelope(&apu.pulse2);
            noiseTickEnvelope(&apu.noise);
            triangleTickLinearCounter(&apu.triangle);

            if (step == 1 or step == 3) {
                pulseTickLengthCounter(&apu.pulse1);
                pulseTickLengthCounter(&apu.pulse2);
                triangleTickLengthCounter(&apu.triangle);
                noiseTickLengthCounter(&apu.noise);

                pulseTickSweep(&apu.pulse1, true);
                pulseTickSweep(&apu.pulse2, false);
            }

            if (step == 3 and !apu.frame_interrupt_inhibit) {
                apu.frame_interrupt = true;
            }
        }
    } else {
        // 5-step mode
        const step = (apu.cycles / step_cycles) % 5;
        const cycle_in_step = apu.cycles % step_cycles;

        if (cycle_in_step == 0) {
            pulseTickEnvelope(&apu.pulse1);
            pulseTickEnvelope(&apu.pulse2);
            noiseTickEnvelope(&apu.noise);
            triangleTickLinearCounter(&apu.triangle);

            if (step == 1 or step == 4) {
                pulseTickLengthCounter(&apu.pulse1);
                pulseTickLengthCounter(&apu.pulse2);
                triangleTickLengthCounter(&apu.triangle);
                noiseTickLengthCounter(&apu.noise);

                pulseTickSweep(&apu.pulse1, true);
                pulseTickSweep(&apu.pulse2, false);
            }
        }
    }
}

// Audio mixing
fn mixAudio(pulse1: u8, pulse2: u8, triangle: u8, noise: u8, dmc: u8) f32 {
    var pulse_out: f32 = 0.0;
    if (pulse1 > 0 or pulse2 > 0) {
        pulse_out = 95.88 / ((8128.0 / @as(f32, @floatFromInt(pulse1 + pulse2))) + 100.0);
    }

    var tnd_out: f32 = 0.0;
    const tnd_sum = (@as(f32, @floatFromInt(triangle)) / 8227.0) +
        (@as(f32, @floatFromInt(noise)) / 12241.0) +
        (@as(f32, @floatFromInt(dmc)) / 22638.0);
    if (tnd_sum > 0) {
        tnd_out = 159.79 / ((1.0 / tnd_sum) + 100.0);
    }

    return pulse_out + tnd_out;
}

fn applyHighpassFilter(apu: *Apu, sample: f32) f32 {
    const alpha: f32 = 0.996;
    const output = alpha * (apu.highpass_prev_out + sample - apu.highpass_prev_in);
    apu.highpass_prev_in = sample;
    apu.highpass_prev_out = output;
    return output;
}

fn applyLowpassFilter(apu: *Apu, sample: f32) f32 {
    const alpha: f32 = 0.53;
    const output = alpha * sample + (1.0 - alpha) * apu.lowpass_prev_out;
    apu.lowpass_prev_out = output;
    return output;
}

// ================================
// Mapper Implementation
// ================================

fn mapperInit(agnes: *Agnes) bool {
    switch (agnes.gamepack.mapper) {
        0 => {
            mapper0Init(&agnes.mapper.m0, agnes);
            return true;
        },
        1 => {
            mapper1Init(&agnes.mapper.m1, agnes);
            return true;
        },
        2 => {
            mapper2Init(&agnes.mapper.m2, agnes);
            return true;
        },
        4 => {
            mapper4Init(&agnes.mapper.m4, agnes);
            return true;
        },
        else => return false,
    }
}

fn mapperRead(agnes: *Agnes, addr: u16) u8 {
    return switch (agnes.gamepack.mapper) {
        0 => mapper0Read(&agnes.mapper.m0, addr),
        1 => mapper1Read(&agnes.mapper.m1, addr),
        2 => mapper2Read(&agnes.mapper.m2, addr),
        4 => mapper4Read(&agnes.mapper.m4, addr),
        else => 0,
    };
}

fn mapperWrite(agnes: *Agnes, addr: u16, val: u8) void {
    switch (agnes.gamepack.mapper) {
        0 => mapper0Write(&agnes.mapper.m0, addr, val),
        1 => mapper1Write(&agnes.mapper.m1, addr, val),
        2 => mapper2Write(&agnes.mapper.m2, addr, val),
        4 => mapper4Write(&agnes.mapper.m4, addr, val),
        else => {},
    }
}

fn mapperPa12RisingEdge(agnes: *Agnes) void {
    switch (agnes.gamepack.mapper) {
        4 => mapper4Pa12RisingEdge(&agnes.mapper.m4),
        else => {},
    }
}

// Mapper 0
fn mapper0Init(mapper: *Mapper0, agnes: *Agnes) void {
    mapper.agnes = agnes;
    mapper.prg_bank_offsets[0] = 0;
    mapper.prg_bank_offsets[1] = if (agnes.gamepack.prg_rom_banks_count > 1) (16 * 1024) else 0;
    mapper.use_chr_ram = agnes.gamepack.chr_rom_banks_count == 0;
}

fn mapper0Read(mapper: *Mapper0, addr: u16) u8 {
    var res: u8 = 0;
    if (addr < 0x2000) {
        if (mapper.use_chr_ram) {
            res = mapper.chr_ram[addr];
        } else {
            const data = mapper.agnes.gamepack.data.?;
            res = data[mapper.agnes.gamepack.chr_rom_offset + addr];
        }
    } else if (addr >= 0x8000) {
        const bank: usize = @intCast((addr >> 14) & 0x1);
        const bank_offset = mapper.prg_bank_offsets[bank];
        const addr_offset = addr & 0x3fff;
        const offset = mapper.agnes.gamepack.prg_rom_offset + bank_offset + addr_offset;
        const data = mapper.agnes.gamepack.data.?;
        res = data[offset];
    }
    return res;
}

fn mapper0Write(mapper: *Mapper0, addr: u16, val: u8) void {
    if (mapper.use_chr_ram and addr < 0x2000) {
        mapper.chr_ram[addr] = val;
    }
}

// Mapper 1
fn mapper1Init(mapper: *Mapper1, agnes: *Agnes) void {
    mapper.agnes = agnes;
    mapper.shift = 0;
    mapper.shift_count = 0;
    mapper.control = 0;
    mapper.prg_mode = 3;
    mapper.chr_mode = 0;
    mapper.chr_banks[0] = 0;
    mapper.chr_banks[1] = 0;
    mapper.prg_bank = 0;
    mapper.use_chr_ram = agnes.gamepack.chr_rom_banks_count == 0;
    mapper1SetOffsets(mapper);
}

fn mapper1Read(mapper: *Mapper1, addr: u16) u8 {
    var res: u8 = 0;
    if (addr < 0x2000) {
        if (mapper.use_chr_ram) {
            res = mapper.chr_ram[addr];
        } else {
            const bank: usize = @intCast((addr >> 12) & 0x1);
            const bank_offset = mapper.chr_bank_offsets[bank];
            const addr_offset = addr & 0xfff;
            const offset = mapper.agnes.gamepack.chr_rom_offset + bank_offset + addr_offset;
            const data = mapper.agnes.gamepack.data.?;
            res = data[offset];
        }
    } else if (addr >= 0x6000 and addr < 0x8000) {
        res = mapper.prg_ram[addr - 0x6000];
    } else if (addr >= 0x8000) {
        const bank: usize = @intCast((addr >> 14) & 0x1);
        const bank_offset = mapper.prg_bank_offsets[bank];
        const addr_offset = addr & 0x3fff;
        const offset = mapper.agnes.gamepack.prg_rom_offset + bank_offset + addr_offset;
        const data = mapper.agnes.gamepack.data.?;
        res = data[offset];
    }
    return res;
}

fn mapper1Write(mapper: *Mapper1, addr: u16, val: u8) void {
    if (addr < 0x2000) {
        if (mapper.use_chr_ram) {
            mapper.chr_ram[addr] = val;
        }
    } else if (addr >= 0x6000 and addr < 0x8000) {
        mapper.prg_ram[addr - 0x6000] = val;
    } else if (addr >= 0x8000) {
        if (getBit(val, 7) != 0) {
            mapper.shift = 0;
            mapper.shift_count = 0;
            mapper1WriteControl(mapper, mapper.control | 0x0c);
            mapper1SetOffsets(mapper);
        } else {
            mapper.shift >>= 1;
            mapper.shift = mapper.shift | ((val & 0x1) << 4);
            mapper.shift_count += 1;
            if (mapper.shift_count == 5) {
                const shift_val = mapper.shift & 0x1f;
                mapper.shift = 0;
                mapper.shift_count = 0;
                const reg: u32 = @intCast((addr >> 13) & 0x3);
                switch (reg) {
                    0 => mapper1WriteControl(mapper, shift_val),
                    1 => mapper.chr_banks[0] = @intCast(shift_val),
                    2 => mapper.chr_banks[1] = @intCast(shift_val),
                    3 => mapper.prg_bank = @intCast(shift_val & 0xf),
                    else => {},
                }
                mapper1SetOffsets(mapper);
            }
        }
    }
}

fn mapper1WriteControl(mapper: *Mapper1, val: u8) void {
    mapper.control = val;
    switch (val & 0x3) {
        0 => mapper.agnes.mirroring_mode = .single_lower,
        1 => mapper.agnes.mirroring_mode = .single_upper,
        2 => mapper.agnes.mirroring_mode = .vertical,
        3 => mapper.agnes.mirroring_mode = .horizontal,
        else => {},
    }
    mapper.prg_mode = @intCast((val >> 2) & 0x3);
    mapper.chr_mode = @intCast((val >> 4) & 0x1);
}

fn mapper1SetOffsets(mapper: *Mapper1) void {
    switch (mapper.chr_mode) {
        0 => {
            mapper.chr_bank_offsets[0] = @intCast((@as(u32, @intCast(mapper.chr_banks[0])) & 0xfe) * (8 * 1024));
            mapper.chr_bank_offsets[1] = @intCast((@as(u32, @intCast(mapper.chr_banks[0])) & 0xfe) * (8 * 1024) + (4 * 1024));
        },
        1 => {
            mapper.chr_bank_offsets[0] = @intCast(@as(u32, @intCast(mapper.chr_banks[0])) * (4 * 1024));
            mapper.chr_bank_offsets[1] = @intCast(@as(u32, @intCast(mapper.chr_banks[1])) * (4 * 1024));
        },
        else => {},
    }

    switch (mapper.prg_mode) {
        0, 1 => {
            mapper.prg_bank_offsets[0] = @intCast((@as(u32, @intCast(mapper.prg_bank)) & 0xe) * (32 * 1024));
            mapper.prg_bank_offsets[1] = @intCast((@as(u32, @intCast(mapper.prg_bank)) & 0xe) * (32 * 1024) + (16 * 1024));
        },
        2 => {
            mapper.prg_bank_offsets[0] = 0;
            mapper.prg_bank_offsets[1] = @intCast(@as(u32, @intCast(mapper.prg_bank)) * (16 * 1024));
        },
        3 => {
            mapper.prg_bank_offsets[0] = @intCast(@as(u32, @intCast(mapper.prg_bank)) * (16 * 1024));
            mapper.prg_bank_offsets[1] = @intCast((@as(u32, @intCast(mapper.agnes.gamepack.prg_rom_banks_count)) - 1) * (16 * 1024));
        },
        else => {},
    }
}

// Mapper 2
fn mapper2Init(mapper: *Mapper2, agnes: *Agnes) void {
    mapper.agnes = agnes;
    mapper.prg_bank_offsets[0] = 0;
    mapper.prg_bank_offsets[1] = @intCast((@as(u32, @intCast(agnes.gamepack.prg_rom_banks_count)) - 1) * (16 * 1024));
}

fn mapper2Read(mapper: *Mapper2, addr: u16) u8 {
    var res: u8 = 0;
    if (addr < 0x2000) {
        res = mapper.chr_ram[addr];
    } else if (addr >= 0x8000) {
        const bank: usize = @intCast((addr >> 14) & 0x1);
        const bank_offset = mapper.prg_bank_offsets[bank];
        const addr_offset = addr & 0x3fff;
        const offset = mapper.agnes.gamepack.prg_rom_offset + bank_offset + addr_offset;
        const data = mapper.agnes.gamepack.data.?;
        res = data[offset];
    }
    return res;
}

fn mapper2Write(mapper: *Mapper2, addr: u16, val: u8) void {
    if (addr < 0x2000) {
        mapper.chr_ram[addr] = val;
    } else if (addr >= 0x8000) {
        const bank = @as(u32, @intCast(val)) % @as(u32, @intCast(mapper.agnes.gamepack.prg_rom_banks_count));
        mapper.prg_bank_offsets[0] = bank * (16 * 1024);
    }
}

// Mapper 4
fn mapper4Init(mapper: *Mapper4, agnes: *Agnes) void {
    mapper.agnes = agnes;
    mapper.prg_mode = 0;
    mapper.chr_mode = 0;
    mapper.irq_enabled = false;
    mapper.reg_ix = 0;
    mapper.regs[0] = 0;
    mapper.regs[1] = 2;
    mapper.regs[2] = 4;
    mapper.regs[3] = 5;
    mapper.regs[4] = 6;
    mapper.regs[5] = 7;
    mapper.regs[6] = 0;
    mapper.regs[7] = 1;
    mapper.counter = 0;
    mapper.counter_reload = 0;
    mapper.use_chr_ram = agnes.gamepack.chr_rom_banks_count == 0;
    mapper4SetOffsets(mapper);
}

fn mapper4Pa12RisingEdge(mapper: *Mapper4) void {
    if (mapper.counter == 0) {
        mapper.counter = mapper.counter_reload;
    } else {
        mapper.counter -= 1;
        if (mapper.counter == 0 and mapper.irq_enabled) {
            cpuTriggerIrq(&mapper.agnes.cpu);
        }
    }
}

fn mapper4Read(mapper: *Mapper4, addr: u16) u8 {
    var res: u8 = 0;
    if (addr < 0x2000) {
        const bank: usize = @intCast((addr >> 10) & 0x7);
        const bank_offset = mapper.chr_bank_offsets[bank];
        const addr_offset = addr & 0x3ff;
        const offset = bank_offset + addr_offset;
        if (mapper.use_chr_ram) {
            const o = offset & ((8 * 1024) - 1);
            res = mapper.chr_ram[o];
        } else {
            const chr_rom_size: u32 = @intCast(@as(u32, @intCast(mapper.agnes.gamepack.chr_rom_banks_count)) * 8 * 1024);
            const o = offset % chr_rom_size;
            const data = mapper.agnes.gamepack.data.?;
            res = data[mapper.agnes.gamepack.chr_rom_offset + o];
        }
    } else if (addr >= 0x6000 and addr < 0x8000) {
        return mapper.prg_ram[addr - 0x6000];
    } else if (addr >= 0x8000) {
        const bank: usize = @intCast((addr >> 13) & 0x3);
        const bank_offset = mapper.prg_bank_offsets[bank];
        const addr_offset = addr & 0x1fff;
        const offset = mapper.agnes.gamepack.prg_rom_offset + bank_offset + addr_offset;
        const data = mapper.agnes.gamepack.data.?;
        res = data[offset];
    }
    return res;
}

fn mapper4Write(mapper: *Mapper4, addr: u16, val: u8) void {
    if (addr < 0x2000 and mapper.use_chr_ram) {
        const bank: usize = @intCast((addr >> 10) & 0x7);
        const bank_offset = mapper.chr_bank_offsets[bank];
        const addr_offset = addr & 0x3ff;
        const full_offset = (bank_offset + addr_offset) & ((8 * 1024) - 1);
        mapper.chr_ram[full_offset] = val;
    } else if (addr >= 0x6000 and addr < 0x8000) {
        mapper.prg_ram[addr - 0x6000] = val;
    } else if (addr >= 0x8000) {
        mapper4WriteRegister(mapper, addr, val);
    }
}

fn mapper4WriteRegister(mapper: *Mapper4, addr: u16, val: u8) void {
    const addr_odd = (addr & 0x1) != 0;
    const addr_even = !addr_odd;
    if (addr <= 0x9ffe and addr_even) {
        mapper.reg_ix = @intCast(val & 0x7);
        mapper.prg_mode = (val >> 6) & 0x1;
        mapper.chr_mode = (val >> 7) & 0x1;
        mapper4SetOffsets(mapper);
    } else if (addr <= 0x9fff and addr_odd) {
        mapper.regs[@intCast(mapper.reg_ix)] = val;
        mapper4SetOffsets(mapper);
    } else if (addr <= 0xbffe and addr_even) {
        if (mapper.agnes.mirroring_mode != .four_screen) {
            mapper.agnes.mirroring_mode = if ((val & 0x1) != 0) .horizontal else .vertical;
        }
    } else if (addr <= 0xdffe and addr_even) {
        mapper.counter_reload = val;
    } else if (addr <= 0xdfff and addr_odd) {
        mapper.counter = 0;
    } else if (addr <= 0xfffe and addr_even) {
        mapper.irq_enabled = false;
    } else if (addr <= 0xffff and addr_odd) {
        mapper.irq_enabled = true;
    }
}

fn mapper4SetOffsets(mapper: *Mapper4) void {
    switch (mapper.chr_mode) {
        0 => {
            mapper.chr_bank_offsets[0] = @intCast((@as(u32, mapper.regs[0]) & 0xfe) * 1024);
            mapper.chr_bank_offsets[1] = @intCast((@as(u32, mapper.regs[0]) & 0xfe) * 1024 + 1024);
            mapper.chr_bank_offsets[2] = @intCast((@as(u32, mapper.regs[1]) & 0xfe) * 1024);
            mapper.chr_bank_offsets[3] = @intCast((@as(u32, mapper.regs[1]) & 0xfe) * 1024 + 1024);
            mapper.chr_bank_offsets[4] = @intCast(@as(u32, mapper.regs[2]) * 1024);
            mapper.chr_bank_offsets[5] = @intCast(@as(u32, mapper.regs[3]) * 1024);
            mapper.chr_bank_offsets[6] = @intCast(@as(u32, mapper.regs[4]) * 1024);
            mapper.chr_bank_offsets[7] = @intCast(@as(u32, mapper.regs[5]) * 1024);
        },
        1 => {
            mapper.chr_bank_offsets[0] = @intCast(@as(u32, mapper.regs[2]) * 1024);
            mapper.chr_bank_offsets[1] = @intCast(@as(u32, mapper.regs[3]) * 1024);
            mapper.chr_bank_offsets[2] = @intCast(@as(u32, mapper.regs[4]) * 1024);
            mapper.chr_bank_offsets[3] = @intCast(@as(u32, mapper.regs[5]) * 1024);
            mapper.chr_bank_offsets[4] = @intCast((@as(u32, mapper.regs[0]) & 0xfe) * 1024);
            mapper.chr_bank_offsets[5] = @intCast((@as(u32, mapper.regs[0]) & 0xfe) * 1024 + 1024);
            mapper.chr_bank_offsets[6] = @intCast((@as(u32, mapper.regs[1]) & 0xfe) * 1024);
            mapper.chr_bank_offsets[7] = @intCast((@as(u32, mapper.regs[1]) & 0xfe) * 1024 + 1024);
        },
        else => {},
    }

    const prg_banks_count: u32 = @intCast(mapper.agnes.gamepack.prg_rom_banks_count);
    switch (mapper.prg_mode) {
        0 => {
            mapper.prg_bank_offsets[0] = @intCast(@as(u32, mapper.regs[6]) * (8 * 1024));
            mapper.prg_bank_offsets[1] = @intCast(@as(u32, mapper.regs[7]) * (8 * 1024));
            mapper.prg_bank_offsets[2] = @intCast((prg_banks_count - 1) * (16 * 1024));
            mapper.prg_bank_offsets[3] = @intCast((prg_banks_count - 1) * (16 * 1024) + (8 * 1024));
        },
        1 => {
            mapper.prg_bank_offsets[0] = @intCast((prg_banks_count - 1) * (16 * 1024));
            mapper.prg_bank_offsets[1] = @intCast(@as(u32, mapper.regs[7]) * (8 * 1024));
            mapper.prg_bank_offsets[2] = @intCast(@as(u32, mapper.regs[6]) * (8 * 1024));
            mapper.prg_bank_offsets[3] = @intCast((prg_banks_count - 1) * (16 * 1024) + (8 * 1024));
        },
        else => {},
    }
}

// ================================
// CPU Instructions Implementation
// Complete 6502 CPU instruction set (56 official instructions)
// ================================

fn opAdc(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const old_acc = cpu.acc;
    const val = cpuRead8(cpu, addr);
    const res: i32 = @as(i32, cpu.acc) + @as(i32, val) + @as(i32, cpu.flag_carry);
    cpu.acc = @truncate(@as(u32, @intCast(res)));
    cpu.flag_carry = if (res > 0xff) 1 else 0;
    cpu.flag_overflow = if (((old_acc ^ val) & 0x80) == 0 and ((old_acc ^ cpu.acc) & 0x80) != 0) 1 else 0;
    cpuUpdateZnFlags(cpu, cpu.acc);
    return 0;
}

fn opAnd(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    cpu.acc = cpu.acc & val;
    cpuUpdateZnFlags(cpu, cpu.acc);
    return 0;
}

fn opAsl(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    if (mode == .accumulator) {
        cpu.flag_carry = getBit(cpu.acc, 7);
        cpu.acc = cpu.acc << 1;
        cpuUpdateZnFlags(cpu, cpu.acc);
    } else {
        const val = cpuRead8(cpu, addr);
        cpu.flag_carry = getBit(val, 7);
        const new_val = val << 1;
        cpuWrite8(cpu, addr, new_val);
        cpuUpdateZnFlags(cpu, new_val);
    }
    return 0;
}

fn opBcc(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    return if (cpu.flag_carry == 0) takeBranch(cpu, addr) else 0;
}

fn opBcs(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    return if (cpu.flag_carry != 0) takeBranch(cpu, addr) else 0;
}

fn opBeq(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    return if (cpu.flag_zero != 0) takeBranch(cpu, addr) else 0;
}

fn opBit(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    const res = cpu.acc & val;
    cpu.flag_zero = if (res == 0) 1 else 0;
    cpu.flag_overflow = getBit(val, 6);
    cpu.flag_negative = getBit(val, 7);
    return 0;
}

fn opBmi(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    return if (cpu.flag_negative != 0) takeBranch(cpu, addr) else 0;
}

fn opBne(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    return if (cpu.flag_zero == 0) takeBranch(cpu, addr) else 0;
}

fn opBpl(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    return if (cpu.flag_negative == 0) takeBranch(cpu, addr) else 0;
}

fn opBrk(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpuStackPush16(cpu, cpu.pc);
    const flags = cpuGetFlags(cpu);
    cpuStackPush8(cpu, flags | 0x30);
    cpu.pc = cpuRead16(cpu, 0xfffe);
    cpu.flag_dis_interrupt = 1;
    return 0;
}

fn opBvc(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    return if (cpu.flag_overflow == 0) takeBranch(cpu, addr) else 0;
}

fn opBvs(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    return if (cpu.flag_overflow != 0) takeBranch(cpu, addr) else 0;
}

fn opClc(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.flag_carry = 0;
    return 0;
}

fn opCld(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.flag_decimal = 0;
    return 0;
}

fn opCli(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.flag_dis_interrupt = 0;
    return 0;
}

fn opClv(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.flag_overflow = 0;
    return 0;
}

fn opCmp(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    cpuUpdateZnFlags(cpu, cpu.acc -% val);
    cpu.flag_carry = if (cpu.acc >= val) 1 else 0;
    return 0;
}

fn opCpx(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    cpuUpdateZnFlags(cpu, cpu.x -% val);
    cpu.flag_carry = if (cpu.x >= val) 1 else 0;
    return 0;
}

fn opCpy(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    cpuUpdateZnFlags(cpu, cpu.y -% val);
    cpu.flag_carry = if (cpu.y >= val) 1 else 0;
    return 0;
}

fn opDec(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    const new_val = val -% 1;
    cpuWrite8(cpu, addr, new_val);
    cpuUpdateZnFlags(cpu, new_val);
    return 0;
}

fn opDex(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.x -%= 1;
    cpuUpdateZnFlags(cpu, cpu.x);
    return 0;
}

fn opDey(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.y -%= 1;
    cpuUpdateZnFlags(cpu, cpu.y);
    return 0;
}

fn opEor(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    cpu.acc = cpu.acc ^ val;
    cpuUpdateZnFlags(cpu, cpu.acc);
    return 0;
}

fn opInc(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    const new_val = val +% 1;
    cpuWrite8(cpu, addr, new_val);
    cpuUpdateZnFlags(cpu, new_val);
    return 0;
}

fn opInx(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.x +%= 1;
    cpuUpdateZnFlags(cpu, cpu.x);
    return 0;
}

fn opIny(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.y +%= 1;
    cpuUpdateZnFlags(cpu, cpu.y);
    return 0;
}

fn opJmp(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    cpu.pc = addr;
    return 0;
}

fn opJsr(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    cpuStackPush16(cpu, cpu.pc -% 1);
    cpu.pc = addr;
    return 0;
}

fn opLda(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    cpu.acc = val;
    cpuUpdateZnFlags(cpu, cpu.acc);
    return 0;
}

fn opLdx(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    cpu.x = val;
    cpuUpdateZnFlags(cpu, cpu.x);
    return 0;
}

fn opLdy(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    cpu.y = val;
    cpuUpdateZnFlags(cpu, cpu.y);
    return 0;
}

fn opLsr(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    if (mode == .accumulator) {
        cpu.flag_carry = getBit(cpu.acc, 0);
        cpu.acc = cpu.acc >> 1;
        cpuUpdateZnFlags(cpu, cpu.acc);
    } else {
        const val = cpuRead8(cpu, addr);
        cpu.flag_carry = getBit(val, 0);
        const new_val = val >> 1;
        cpuWrite8(cpu, addr, new_val);
        cpuUpdateZnFlags(cpu, new_val);
    }
    return 0;
}

fn opNop(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = cpu;
    _ = addr;
    _ = mode;
    return 0;
}

fn opOra(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    cpu.acc = cpu.acc | val;
    cpuUpdateZnFlags(cpu, cpu.acc);
    return 0;
}

fn opPha(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpuStackPush8(cpu, cpu.acc);
    return 0;
}

fn opPhp(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    const flags = cpuGetFlags(cpu);
    cpuStackPush8(cpu, flags | 0x30);
    return 0;
}

fn opPla(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.acc = cpuStackPop8(cpu);
    cpuUpdateZnFlags(cpu, cpu.acc);
    return 0;
}

fn opPlp(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    const flags = cpuStackPop8(cpu);
    cpuRestoreFlags(cpu, flags);
    return 0;
}

fn opRol(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    const old_carry = cpu.flag_carry;
    if (mode == .accumulator) {
        cpu.flag_carry = getBit(cpu.acc, 7);
        cpu.acc = (cpu.acc << 1) | old_carry;
        cpuUpdateZnFlags(cpu, cpu.acc);
    } else {
        const val = cpuRead8(cpu, addr);
        cpu.flag_carry = getBit(val, 7);
        const new_val = (val << 1) | old_carry;
        cpuWrite8(cpu, addr, new_val);
        cpuUpdateZnFlags(cpu, new_val);
    }
    return 0;
}

fn opRor(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    const old_carry = cpu.flag_carry;
    if (mode == .accumulator) {
        cpu.flag_carry = getBit(cpu.acc, 0);
        cpu.acc = (cpu.acc >> 1) | (old_carry << 7);
        cpuUpdateZnFlags(cpu, cpu.acc);
    } else {
        const val = cpuRead8(cpu, addr);
        cpu.flag_carry = getBit(val, 0);
        const new_val = (val >> 1) | (old_carry << 7);
        cpuWrite8(cpu, addr, new_val);
        cpuUpdateZnFlags(cpu, new_val);
    }
    return 0;
}

fn opRti(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    const flags = cpuStackPop8(cpu);
    cpuRestoreFlags(cpu, flags);
    cpu.pc = cpuStackPop16(cpu);
    return 0;
}

fn opRts(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.pc = cpuStackPop16(cpu) +% 1;
    return 0;
}

fn opSbc(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    const val = cpuRead8(cpu, addr);
    const old_acc = cpu.acc;
    const res: i32 = @as(i32, cpu.acc) - @as(i32, val) - @as(i32, if (cpu.flag_carry != 0) 0 else 1);
    cpu.acc = @truncate(@as(u32, @intCast(res & 0xFF)));
    cpuUpdateZnFlags(cpu, cpu.acc);
    cpu.flag_carry = if (res >= 0) 1 else 0;
    cpu.flag_overflow = if (((old_acc ^ val) & 0x80) != 0 and ((old_acc ^ cpu.acc) & 0x80) != 0) 1 else 0;
    return 0;
}

fn opSec(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.flag_carry = 1;
    return 0;
}

fn opSed(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.flag_decimal = 1;
    return 0;
}

fn opSei(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.flag_dis_interrupt = 1;
    return 0;
}

fn opSta(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    cpuWrite8(cpu, addr, cpu.acc);
    return 0;
}

fn opStx(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    cpuWrite8(cpu, addr, cpu.x);
    return 0;
}

fn opSty(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = mode;
    cpuWrite8(cpu, addr, cpu.y);
    return 0;
}

fn opTax(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.x = cpu.acc;
    cpuUpdateZnFlags(cpu, cpu.x);
    return 0;
}

fn opTay(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.y = cpu.acc;
    cpuUpdateZnFlags(cpu, cpu.y);
    return 0;
}

fn opTsx(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.x = cpu.sp;
    cpuUpdateZnFlags(cpu, cpu.x);
    return 0;
}

fn opTxa(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.acc = cpu.x;
    cpuUpdateZnFlags(cpu, cpu.acc);
    return 0;
}

fn opTxs(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.sp = cpu.x;
    return 0;
}

fn opTya(cpu: *Cpu, addr: u16, mode: AddrMode) i32 {
    _ = addr;
    _ = mode;
    cpu.acc = cpu.y;
    cpuUpdateZnFlags(cpu, cpu.acc);
    return 0;
}

fn takeBranch(cpu: *Cpu, addr: u16) i32 {
    const page_crossed = (cpu.pc & 0xff00) != (addr & 0xff00);
    cpu.pc = addr;
    return if (page_crossed) 2 else 1;
}

// Full 256-entry instruction table
const instructions = [256]Instruction{
    .{ .name = "BRK", .opcode = 0x00, .cycles = 7, .page_cross_cycle = false, .mode = .implied_brk, .operation = opBrk },
    .{ .name = "ORA", .opcode = 0x01, .cycles = 6, .page_cross_cycle = false, .mode = .indirect_x, .operation = opOra },
    .{ .name = "ILL", .opcode = 0x02, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x03, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x04, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ORA", .opcode = 0x05, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opOra },
    .{ .name = "ASL", .opcode = 0x06, .cycles = 5, .page_cross_cycle = false, .mode = .zero_page, .operation = opAsl },
    .{ .name = "ILL", .opcode = 0x07, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "PHP", .opcode = 0x08, .cycles = 3, .page_cross_cycle = false, .mode = .implied, .operation = opPhp },
    .{ .name = "ORA", .opcode = 0x09, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opOra },
    .{ .name = "ASL", .opcode = 0x0a, .cycles = 2, .page_cross_cycle = false, .mode = .accumulator, .operation = opAsl },
    .{ .name = "ILL", .opcode = 0x0b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x0c, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ORA", .opcode = 0x0d, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opOra },
    .{ .name = "ASL", .opcode = 0x0e, .cycles = 6, .page_cross_cycle = false, .mode = .absolute, .operation = opAsl },
    .{ .name = "ILL", .opcode = 0x0f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BPL", .opcode = 0x10, .cycles = 2, .page_cross_cycle = true, .mode = .relative, .operation = opBpl },
    .{ .name = "ORA", .opcode = 0x11, .cycles = 5, .page_cross_cycle = true, .mode = .indirect_y, .operation = opOra },
    .{ .name = "ILL", .opcode = 0x12, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x13, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x14, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ORA", .opcode = 0x15, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opOra },
    .{ .name = "ASL", .opcode = 0x16, .cycles = 6, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opAsl },
    .{ .name = "ILL", .opcode = 0x17, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CLC", .opcode = 0x18, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opClc },
    .{ .name = "ORA", .opcode = 0x19, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_y, .operation = opOra },
    .{ .name = "ILL", .opcode = 0x1a, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x1b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x1c, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ORA", .opcode = 0x1d, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_x, .operation = opOra },
    .{ .name = "ASL", .opcode = 0x1e, .cycles = 7, .page_cross_cycle = false, .mode = .absolute_x, .operation = opAsl },
    .{ .name = "ILL", .opcode = 0x1f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "JSR", .opcode = 0x20, .cycles = 6, .page_cross_cycle = false, .mode = .absolute, .operation = opJsr },
    .{ .name = "AND", .opcode = 0x21, .cycles = 6, .page_cross_cycle = false, .mode = .indirect_x, .operation = opAnd },
    .{ .name = "ILL", .opcode = 0x22, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x23, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BIT", .opcode = 0x24, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opBit },
    .{ .name = "AND", .opcode = 0x25, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opAnd },
    .{ .name = "ROL", .opcode = 0x26, .cycles = 5, .page_cross_cycle = false, .mode = .zero_page, .operation = opRol },
    .{ .name = "ILL", .opcode = 0x27, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "PLP", .opcode = 0x28, .cycles = 4, .page_cross_cycle = false, .mode = .implied, .operation = opPlp },
    .{ .name = "AND", .opcode = 0x29, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opAnd },
    .{ .name = "ROL", .opcode = 0x2a, .cycles = 2, .page_cross_cycle = false, .mode = .accumulator, .operation = opRol },
    .{ .name = "ILL", .opcode = 0x2b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BIT", .opcode = 0x2c, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opBit },
    .{ .name = "AND", .opcode = 0x2d, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opAnd },
    .{ .name = "ROL", .opcode = 0x2e, .cycles = 6, .page_cross_cycle = false, .mode = .absolute, .operation = opRol },
    .{ .name = "ILL", .opcode = 0x2f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BMI", .opcode = 0x30, .cycles = 2, .page_cross_cycle = true, .mode = .relative, .operation = opBmi },
    .{ .name = "AND", .opcode = 0x31, .cycles = 5, .page_cross_cycle = true, .mode = .indirect_y, .operation = opAnd },
    .{ .name = "ILL", .opcode = 0x32, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x33, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x34, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "AND", .opcode = 0x35, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opAnd },
    .{ .name = "ROL", .opcode = 0x36, .cycles = 6, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opRol },
    .{ .name = "ILL", .opcode = 0x37, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "SEC", .opcode = 0x38, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opSec },
    .{ .name = "AND", .opcode = 0x39, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_y, .operation = opAnd },
    .{ .name = "ILL", .opcode = 0x3a, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x3b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x3c, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "AND", .opcode = 0x3d, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_x, .operation = opAnd },
    .{ .name = "ROL", .opcode = 0x3e, .cycles = 7, .page_cross_cycle = false, .mode = .absolute_x, .operation = opRol },
    .{ .name = "ILL", .opcode = 0x3f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "RTI", .opcode = 0x40, .cycles = 6, .page_cross_cycle = false, .mode = .implied, .operation = opRti },
    .{ .name = "EOR", .opcode = 0x41, .cycles = 6, .page_cross_cycle = false, .mode = .indirect_x, .operation = opEor },
    .{ .name = "ILL", .opcode = 0x42, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x43, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x44, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "EOR", .opcode = 0x45, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opEor },
    .{ .name = "LSR", .opcode = 0x46, .cycles = 5, .page_cross_cycle = false, .mode = .zero_page, .operation = opLsr },
    .{ .name = "ILL", .opcode = 0x47, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "PHA", .opcode = 0x48, .cycles = 3, .page_cross_cycle = false, .mode = .implied, .operation = opPha },
    .{ .name = "EOR", .opcode = 0x49, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opEor },
    .{ .name = "LSR", .opcode = 0x4a, .cycles = 2, .page_cross_cycle = false, .mode = .accumulator, .operation = opLsr },
    .{ .name = "ILL", .opcode = 0x4b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "JMP", .opcode = 0x4c, .cycles = 3, .page_cross_cycle = false, .mode = .absolute, .operation = opJmp },
    .{ .name = "EOR", .opcode = 0x4d, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opEor },
    .{ .name = "LSR", .opcode = 0x4e, .cycles = 6, .page_cross_cycle = false, .mode = .absolute, .operation = opLsr },
    .{ .name = "ILL", .opcode = 0x4f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BVC", .opcode = 0x50, .cycles = 2, .page_cross_cycle = true, .mode = .relative, .operation = opBvc },
    .{ .name = "EOR", .opcode = 0x51, .cycles = 5, .page_cross_cycle = true, .mode = .indirect_y, .operation = opEor },
    .{ .name = "ILL", .opcode = 0x52, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x53, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x54, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "EOR", .opcode = 0x55, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opEor },
    .{ .name = "LSR", .opcode = 0x56, .cycles = 6, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opLsr },
    .{ .name = "ILL", .opcode = 0x57, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CLI", .opcode = 0x58, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opCli },
    .{ .name = "EOR", .opcode = 0x59, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_y, .operation = opEor },
    .{ .name = "ILL", .opcode = 0x5a, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x5b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x5c, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "EOR", .opcode = 0x5d, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_x, .operation = opEor },
    .{ .name = "LSR", .opcode = 0x5e, .cycles = 7, .page_cross_cycle = false, .mode = .absolute_x, .operation = opLsr },
    .{ .name = "ILL", .opcode = 0x5f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "RTS", .opcode = 0x60, .cycles = 6, .page_cross_cycle = false, .mode = .implied, .operation = opRts },
    .{ .name = "ADC", .opcode = 0x61, .cycles = 6, .page_cross_cycle = false, .mode = .indirect_x, .operation = opAdc },
    .{ .name = "ILL", .opcode = 0x62, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x63, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x64, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ADC", .opcode = 0x65, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opAdc },
    .{ .name = "ROR", .opcode = 0x66, .cycles = 5, .page_cross_cycle = false, .mode = .zero_page, .operation = opRor },
    .{ .name = "ILL", .opcode = 0x67, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "PLA", .opcode = 0x68, .cycles = 4, .page_cross_cycle = false, .mode = .implied, .operation = opPla },
    .{ .name = "ADC", .opcode = 0x69, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opAdc },
    .{ .name = "ROR", .opcode = 0x6a, .cycles = 2, .page_cross_cycle = false, .mode = .accumulator, .operation = opRor },
    .{ .name = "ILL", .opcode = 0x6b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "JMP", .opcode = 0x6c, .cycles = 5, .page_cross_cycle = false, .mode = .indirect, .operation = opJmp },
    .{ .name = "ADC", .opcode = 0x6d, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opAdc },
    .{ .name = "ROR", .opcode = 0x6e, .cycles = 6, .page_cross_cycle = false, .mode = .absolute, .operation = opRor },
    .{ .name = "ILL", .opcode = 0x6f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BVS", .opcode = 0x70, .cycles = 2, .page_cross_cycle = true, .mode = .relative, .operation = opBvs },
    .{ .name = "ADC", .opcode = 0x71, .cycles = 5, .page_cross_cycle = true, .mode = .indirect_y, .operation = opAdc },
    .{ .name = "ILL", .opcode = 0x72, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x73, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x74, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ADC", .opcode = 0x75, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opAdc },
    .{ .name = "ROR", .opcode = 0x76, .cycles = 6, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opRor },
    .{ .name = "ILL", .opcode = 0x77, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "SEI", .opcode = 0x78, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opSei },
    .{ .name = "ADC", .opcode = 0x79, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_y, .operation = opAdc },
    .{ .name = "ILL", .opcode = 0x7a, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x7b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x7c, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ADC", .opcode = 0x7d, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_x, .operation = opAdc },
    .{ .name = "ROR", .opcode = 0x7e, .cycles = 7, .page_cross_cycle = false, .mode = .absolute_x, .operation = opRor },
    .{ .name = "ILL", .opcode = 0x7f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x80, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "STA", .opcode = 0x81, .cycles = 6, .page_cross_cycle = false, .mode = .indirect_x, .operation = opSta },
    .{ .name = "ILL", .opcode = 0x82, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x83, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "STY", .opcode = 0x84, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opSty },
    .{ .name = "STA", .opcode = 0x85, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opSta },
    .{ .name = "STX", .opcode = 0x86, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opStx },
    .{ .name = "ILL", .opcode = 0x87, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "DEY", .opcode = 0x88, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opDey },
    .{ .name = "ILL", .opcode = 0x89, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "TXA", .opcode = 0x8a, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opTxa },
    .{ .name = "ILL", .opcode = 0x8b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "STY", .opcode = 0x8c, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opSty },
    .{ .name = "STA", .opcode = 0x8d, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opSta },
    .{ .name = "STX", .opcode = 0x8e, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opStx },
    .{ .name = "ILL", .opcode = 0x8f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BCC", .opcode = 0x90, .cycles = 2, .page_cross_cycle = true, .mode = .relative, .operation = opBcc },
    .{ .name = "STA", .opcode = 0x91, .cycles = 6, .page_cross_cycle = false, .mode = .indirect_y, .operation = opSta },
    .{ .name = "ILL", .opcode = 0x92, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x93, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "STY", .opcode = 0x94, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opSty },
    .{ .name = "STA", .opcode = 0x95, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opSta },
    .{ .name = "STX", .opcode = 0x96, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_y, .operation = opStx },
    .{ .name = "ILL", .opcode = 0x97, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "TYA", .opcode = 0x98, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opTya },
    .{ .name = "STA", .opcode = 0x99, .cycles = 5, .page_cross_cycle = false, .mode = .absolute_y, .operation = opSta },
    .{ .name = "TXS", .opcode = 0x9a, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opTxs },
    .{ .name = "ILL", .opcode = 0x9b, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x9c, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "STA", .opcode = 0x9d, .cycles = 5, .page_cross_cycle = false, .mode = .absolute_x, .operation = opSta },
    .{ .name = "ILL", .opcode = 0x9e, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0x9f, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "LDY", .opcode = 0xa0, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opLdy },
    .{ .name = "LDA", .opcode = 0xa1, .cycles = 6, .page_cross_cycle = false, .mode = .indirect_x, .operation = opLda },
    .{ .name = "LDX", .opcode = 0xa2, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opLdx },
    .{ .name = "ILL", .opcode = 0xa3, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "LDY", .opcode = 0xa4, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opLdy },
    .{ .name = "LDA", .opcode = 0xa5, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opLda },
    .{ .name = "LDX", .opcode = 0xa6, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opLdx },
    .{ .name = "ILL", .opcode = 0xa7, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "TAY", .opcode = 0xa8, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opTay },
    .{ .name = "LDA", .opcode = 0xa9, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opLda },
    .{ .name = "TAX", .opcode = 0xaa, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opTax },
    .{ .name = "ILL", .opcode = 0xab, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "LDY", .opcode = 0xac, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opLdy },
    .{ .name = "LDA", .opcode = 0xad, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opLda },
    .{ .name = "LDX", .opcode = 0xae, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opLdx },
    .{ .name = "ILL", .opcode = 0xaf, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BCS", .opcode = 0xb0, .cycles = 2, .page_cross_cycle = true, .mode = .relative, .operation = opBcs },
    .{ .name = "LDA", .opcode = 0xb1, .cycles = 5, .page_cross_cycle = true, .mode = .indirect_y, .operation = opLda },
    .{ .name = "ILL", .opcode = 0xb2, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xb3, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "LDY", .opcode = 0xb4, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opLdy },
    .{ .name = "LDA", .opcode = 0xb5, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opLda },
    .{ .name = "LDX", .opcode = 0xb6, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_y, .operation = opLdx },
    .{ .name = "ILL", .opcode = 0xb7, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CLV", .opcode = 0xb8, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opClv },
    .{ .name = "LDA", .opcode = 0xb9, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_y, .operation = opLda },
    .{ .name = "TSX", .opcode = 0xba, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opTsx },
    .{ .name = "ILL", .opcode = 0xbb, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "LDY", .opcode = 0xbc, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_x, .operation = opLdy },
    .{ .name = "LDA", .opcode = 0xbd, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_x, .operation = opLda },
    .{ .name = "LDX", .opcode = 0xbe, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_y, .operation = opLdx },
    .{ .name = "ILL", .opcode = 0xbf, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CPY", .opcode = 0xc0, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opCpy },
    .{ .name = "CMP", .opcode = 0xc1, .cycles = 6, .page_cross_cycle = false, .mode = .indirect_x, .operation = opCmp },
    .{ .name = "ILL", .opcode = 0xc2, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xc3, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CPY", .opcode = 0xc4, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opCpy },
    .{ .name = "CMP", .opcode = 0xc5, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opCmp },
    .{ .name = "DEC", .opcode = 0xc6, .cycles = 5, .page_cross_cycle = false, .mode = .zero_page, .operation = opDec },
    .{ .name = "ILL", .opcode = 0xc7, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "INY", .opcode = 0xc8, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opIny },
    .{ .name = "CMP", .opcode = 0xc9, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opCmp },
    .{ .name = "DEX", .opcode = 0xca, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opDex },
    .{ .name = "ILL", .opcode = 0xcb, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CPY", .opcode = 0xcc, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opCpy },
    .{ .name = "CMP", .opcode = 0xcd, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opCmp },
    .{ .name = "DEC", .opcode = 0xce, .cycles = 6, .page_cross_cycle = false, .mode = .absolute, .operation = opDec },
    .{ .name = "ILL", .opcode = 0xcf, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BNE", .opcode = 0xd0, .cycles = 2, .page_cross_cycle = true, .mode = .relative, .operation = opBne },
    .{ .name = "CMP", .opcode = 0xd1, .cycles = 5, .page_cross_cycle = true, .mode = .indirect_y, .operation = opCmp },
    .{ .name = "ILL", .opcode = 0xd2, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xd3, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xd4, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CMP", .opcode = 0xd5, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opCmp },
    .{ .name = "DEC", .opcode = 0xd6, .cycles = 6, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opDec },
    .{ .name = "ILL", .opcode = 0xd7, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CLD", .opcode = 0xd8, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opCld },
    .{ .name = "CMP", .opcode = 0xd9, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_y, .operation = opCmp },
    .{ .name = "ILL", .opcode = 0xda, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xdb, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xdc, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CMP", .opcode = 0xdd, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_x, .operation = opCmp },
    .{ .name = "DEC", .opcode = 0xde, .cycles = 7, .page_cross_cycle = false, .mode = .absolute_x, .operation = opDec },
    .{ .name = "ILL", .opcode = 0xdf, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CPX", .opcode = 0xe0, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opCpx },
    .{ .name = "SBC", .opcode = 0xe1, .cycles = 6, .page_cross_cycle = false, .mode = .indirect_x, .operation = opSbc },
    .{ .name = "ILL", .opcode = 0xe2, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xe3, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CPX", .opcode = 0xe4, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opCpx },
    .{ .name = "SBC", .opcode = 0xe5, .cycles = 3, .page_cross_cycle = false, .mode = .zero_page, .operation = opSbc },
    .{ .name = "INC", .opcode = 0xe6, .cycles = 5, .page_cross_cycle = false, .mode = .zero_page, .operation = opInc },
    .{ .name = "ILL", .opcode = 0xe7, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "INX", .opcode = 0xe8, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opInx },
    .{ .name = "SBC", .opcode = 0xe9, .cycles = 2, .page_cross_cycle = false, .mode = .immediate, .operation = opSbc },
    .{ .name = "NOP", .opcode = 0xea, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xeb, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "CPX", .opcode = 0xec, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opCpx },
    .{ .name = "SBC", .opcode = 0xed, .cycles = 4, .page_cross_cycle = false, .mode = .absolute, .operation = opSbc },
    .{ .name = "INC", .opcode = 0xee, .cycles = 6, .page_cross_cycle = false, .mode = .absolute, .operation = opInc },
    .{ .name = "ILL", .opcode = 0xef, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "BEQ", .opcode = 0xf0, .cycles = 2, .page_cross_cycle = true, .mode = .relative, .operation = opBeq },
    .{ .name = "SBC", .opcode = 0xf1, .cycles = 5, .page_cross_cycle = true, .mode = .indirect_y, .operation = opSbc },
    .{ .name = "ILL", .opcode = 0xf2, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xf3, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xf4, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "SBC", .opcode = 0xf5, .cycles = 4, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opSbc },
    .{ .name = "INC", .opcode = 0xf6, .cycles = 6, .page_cross_cycle = false, .mode = .zero_page_x, .operation = opInc },
    .{ .name = "ILL", .opcode = 0xf7, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "SED", .opcode = 0xf8, .cycles = 2, .page_cross_cycle = false, .mode = .implied, .operation = opSed },
    .{ .name = "SBC", .opcode = 0xf9, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_y, .operation = opSbc },
    .{ .name = "ILL", .opcode = 0xfa, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xfb, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "ILL", .opcode = 0xfc, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
    .{ .name = "SBC", .opcode = 0xfd, .cycles = 4, .page_cross_cycle = true, .mode = .absolute_x, .operation = opSbc },
    .{ .name = "INC", .opcode = 0xfe, .cycles = 7, .page_cross_cycle = false, .mode = .absolute_x, .operation = opInc },
    .{ .name = "ILL", .opcode = 0xff, .cycles = 1, .page_cross_cycle = false, .mode = .implied, .operation = opNop },
};

fn instructionGet(opcode: u8) Instruction {
    return instructions[opcode];
}

fn instructionGetSize(mode: AddrMode) u16 {
    return switch (mode) {
        .none => 0,
        .absolute, .absolute_x, .absolute_y, .indirect => 3,
        .accumulator, .implied => 1,
        .immediate, .implied_brk, .indirect_x, .indirect_y, .relative, .zero_page, .zero_page_x, .zero_page_y => 2,
    };
}

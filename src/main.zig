const std = @import("std");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const shd = @import("shaders/triangle.glsl.zig");
const c = @cImport(@cInclude("agnes.h"));

const NES_WIDTH = 256;
const NES_HEIGHT = 240;

const state = struct {
    var bind: sg.Bindings = .{};
    var pip: sg.Pipeline = .{};
    var input: c.agnes_input_t = .{
        .a = false,
        .b = false,
        .select = false,
        .start = false,
        .up = false,
        .down = false,
        .left = false,
        .right = false,
    };
    var agnes: ?*c.agnes_t = null;
};
pub var pixel_buffer: [NES_WIDTH * NES_HEIGHT]u32 = undefined;

export fn init() void {
    // init agnes
    state.agnes = c.agnes_make();
    // const rom = "roms/mario.nes";
    // const rom = "roms/NinjaGaiden.nes";
    const rom = "roms/hello.nes";
    const ok = c.agnes_load_ines_data_from_path(state.agnes, rom);
    if (!ok) {
        std.log.err("Loading {s} failed.\n\n", .{rom});
    }

    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]f32{
            // positions     uv
            -1.0, -1.0, 0.0, 0.0, 1.0,
            1.0,  -1.0, 0.0, 1.0, 1.0,
            1.0,  1.0,  0.0, 1.0, 0.0,
            -1.0, 1.0,  0.0, 0.0, 0.0,
        }),
    });

    state.bind.index_buffer = sg.makeBuffer(.{ .type = .INDEXBUFFER, .data = sg.asRange(&[_]u16{
        0, 1, 2, 0, 2, 3,
    }) });

    const img_desc: sg.ImageDesc = .{
        .width = NES_WIDTH,
        .height = NES_HEIGHT,
        .pixel_format = .RGBA8,
        .usage = .STREAM,
    };
    var X: usize = 0;
    var Y: usize = 0;
    while (Y < NES_HEIGHT) : (Y += 1) {
        X = 0;
        while (X < NES_WIDTH) : (X += 1) {
            pixel_buffer[X + Y * NES_WIDTH] = 0xFF0000FF;
        }
    }
    state.bind.images[shd.IMG_tex] = sg.makeImage(img_desc);

    state.bind.samplers[shd.SMP_smp] = sg.makeSampler(.{
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
        .wrap_u = .REPEAT,
        .wrap_v = .REPEAT,
    });

    state.pip = sg.makePipeline(.{
        .shader = sg.makeShader(shd.triangleShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.attrs[shd.ATTR_triangle_position].format = .FLOAT3;
            l.attrs[shd.ATTR_triangle_texcoord0].format = .FLOAT2;
            break :init l;
        },
        .index_type = .UINT16,
    });
}

export fn frame() void {
    // agnes update
    const tmpinput = &state.input;
    c.agnes_set_input(state.agnes, tmpinput, null);

    const ok = c.agnes_next_frame(state.agnes);
    if (!ok) {
        std.log.err("Getting next frame failed.\n", .{});
    }

    var X: i32 = 0;
    var Y: i32 = 0;
    while (Y < NES_HEIGHT) : (Y += 1) {
        X = 0;
        while (X < NES_WIDTH) : (X += 1) {
            const color = c.agnes_get_screen_pixel(state.agnes, X, Y);
            const colorABGR: u32 = @as(u32, color.r) | @as(u32, color.g) << 8 | @as(u32, color.b) << 16 | 0xff << 24;
            pixel_buffer[@intCast(X + Y * NES_WIDTH)] = colorABGR;
        }
    }

    // copy emulator pixel data into upscaling source texture
    var image_data = sg.ImageData{};
    image_data.subimage[0][0] = sg.asRange(&pixel_buffer);
    sg.updateImage(state.bind.images[shd.IMG_tex], image_data);

    // default pass-action clears to grey
    sg.beginPass(.{ .swapchain = sglue.swapchain() });
    sg.applyPipeline(state.pip);
    sg.applyBindings(state.bind);
    sg.draw(0, 6, 1);
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sg.shutdown();
    c.agnes_destroy(state.agnes);
}

export fn input(event: ?*const sapp.Event) void {
    const ev = event.?;
    switch (ev.type) {
        .KEY_DOWN => {
            switch (ev.key_code) {
                .ENTER => state.input.start = true,
                .RIGHT => state.input.right = true,
                .LEFT => state.input.left = true,
                .DOWN => state.input.down = true,
                .UP => state.input.up = true,
                .BACKSPACE => state.input.select = true,
                .Z => state.input.a = true,
                .X => state.input.b = true,
                else => {},
            }
        },
        .KEY_UP => {
            switch (ev.key_code) {
                .ENTER => state.input.start = false,
                .RIGHT => state.input.right = false,
                .LEFT => state.input.left = false,
                .DOWN => state.input.down = false,
                .UP => state.input.up = false,
                .BACKSPACE => state.input.select = false,
                .Z => state.input.a = false,
                .X => state.input.b = false,
                else => {},
            }
        },
        else => {},
    }
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = input,
        .width = NES_WIDTH,
        .height = NES_HEIGHT,
        .icon = .{ .sokol_default = true },
        .window_title = "nesemu.zig",
        .logger = .{ .func = slog.func },
    });
}

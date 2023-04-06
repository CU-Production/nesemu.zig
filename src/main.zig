const std = @import("std");
const sokol = @import("sokol");
const c = @cImport(@cInclude("agnes.h"));
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

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
    var ok = c.agnes_load_ines_data_from_path(state.agnes, rom);
    if (!ok) {
        std.log.err("Loading {s} failed.\n\n", .{rom});
    }

    // init sokol
    sg.setup(.{
        .context = sgapp.context(),
        .logger = .{ .func = slog.func },
    });

    // create vertex buffer with triangle vertices
    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&[_]f32{
            // positions     uv
            -1.0, -1.0, 0.0, 0.0, 1.0,
            1.0,  -1.0, 0.0, 1.0, 1.0,
            1.0,  1.0,  0.0, 1.0, 0.0,
            -1.0, 1.0,  0.0, 0.0, 0.0,
        }),
    });

    // cube index buffer
    state.bind.index_buffer = sg.makeBuffer(.{ .type = .INDEXBUFFER, .data = sg.asRange(&[_]u16{
        0, 1, 2, 0, 2, 3,
    }) });

    // create a small checker-board texture
    var img_desc: sg.ImageDesc = .{
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
    state.bind.fs_images[0] = sg.makeImage(img_desc);

    // create a shader and pipeline object
    const shd = sg.makeShader(shaderDesc());
    var pip_desc: sg.PipelineDesc = .{
        .shader = shd,
        .index_type = .UINT16,
    };
    pip_desc.layout.attrs[0].format = .FLOAT3;
    pip_desc.layout.attrs[1].format = .FLOAT2;
    state.pip = sg.makePipeline(pip_desc);
}

export fn frame() void {
    // agnes update
    var tmpinput = &state.input;
    c.agnes_set_input(state.agnes, tmpinput, null);

    var ok = c.agnes_next_frame(state.agnes);
    if (!ok) {
        std.log.err("Getting next frame failed.\n", .{});
    }

    var X: i32 = 0;
    var Y: i32 = 0;
    while (Y < NES_HEIGHT) : (Y += 1) {
        X = 0;
        while (X < NES_WIDTH) : (X += 1) {
            var color = c.agnes_get_screen_pixel(state.agnes, X, Y);
            var colorABGR: u32 = @as(u32, color.r) | @as(u32, color.g) << 8 | @as(u32, color.b) << 16 | 0xff << 24;
            pixel_buffer[@intCast(usize, X + Y * NES_WIDTH)] = colorABGR;
        }
    }

    // copy emulator pixel data into upscaling source texture
    var image_data = sg.ImageData{};
    image_data.subimage[0][0] = sg.asRange(&pixel_buffer);
    sg.updateImage(state.bind.fs_images[0], image_data);

    // default pass-action clears to grey
    sg.beginDefaultPass(.{}, sapp.width(), sapp.height());
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

pub fn main() !void {
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

fn shaderDesc() sg.ShaderDesc {
    var desc: sg.ShaderDesc = .{};
    switch (sg.queryBackend()) {
        .D3D11 => {
            desc.attrs[0].sem_name = "TEXCOORD";
            desc.attrs[0].sem_index = 0;
            desc.attrs[1].sem_name = "TEXCOORD";
            desc.attrs[1].sem_index = 1;
            desc.vs.source =
                \\struct vs_in {
                \\  float3 pos : TEXCOORD0;
                \\  float2 texcoord0 : TEXCOORD1;
                \\};
                \\struct vs_out {
                \\  float4 pos: SV_Position;
                \\  float4 color : TEXCOORD0;
                \\  float2 uv : TEXCOORD1;
                \\};
                \\vs_out main(vs_in inp) {
                \\  vs_out outp;
                \\  outp.pos = float4(inp.pos, 1.0f);
                \\  outp.uv = inp.texcoord0;
                \\  outp.color = float4(outp.uv, 0.0f, 1.0f);
                \\  return outp;
                \\}
            ;
            desc.fs.images[0].name = "tex";
            desc.fs.images[0].image_type = ._2D;
            desc.fs.images[0].sampler_type = .FLOAT;
            desc.fs.source =
                \\Texture2D<float4> tex : register(t0);
                \\SamplerState _tex_sampler : register(s0);
                \\struct ps_in
                \\{
                \\    float4 color : TEXCOORD0;
                \\    float2 uv : TEXCOORD1;
                \\};
                \\float4 main(ps_in stage_input): SV_Target0 {
                \\  float4 color = tex.Sample(_tex_sampler, stage_input.uv);
                \\  return float4(color.rgb, 1.0f);
                \\}
            ;
        },
        .GLCORE33 => {
            desc.attrs[0].name = "position";
            desc.attrs[1].name = "texcoord0";
            desc.vs.source =
                \\ #version 330
                \\ in vec3 position;
                \\ in vec2 texcoord0;
                \\ out vec4 color;
                \\ out vec2 uv;
                \\ void main() {
                \\   gl_Position = vec4(position, 1.0f);
                \\   uv = texcoord0;
                \\   color = vec4(uv, 0.0f, 1.0f);
                \\ }
            ;
            desc.fs.images[0].name = "tex";
            desc.fs.images[0].image_type = ._2D;
            desc.fs.images[0].sampler_type = .FLOAT;
            desc.fs.source =
                \\ #version 330
                \\ uniform sampler2D tex;
                \\ in vec4 color;
                \\ in vec2 uv;
                \\ out vec4 frag_color;
                \\ void main() {
                \\   frag_color = texture(tex, uv);
                \\ }
            ;
        },
        else => {},
    }
    return desc;
}

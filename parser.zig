const std = @import("std");
const expect = @import("std").testing.expect;
const File = @import("std").fs.File;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("cat.jpeg", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.print("mem leak", .{});
    }

    const soi: bool = try validateSOI(file, allocator);
    std.debug.assert(soi);

    try readAPP0(file, allocator);
}

fn hexSliceToInt(bytes: []u8) u64 {
    var ret: u64 = 0;
    for (bytes, 0..) |byte, i| {
        const iter: u8 = @as(u8, @intCast(bytes.len - 1 - i));
        ret += byte * std.math.pow(u8, 0xFF, iter);
    }
    return ret;
}

fn readAPP0(file: File, allocator: std.mem.Allocator) !void {
    const marker: []u8 = try readBytes(file, allocator, 2);
    defer allocator.free(marker);
    if (marker[0] != 0xFF and marker[1] != 0xE0) unreachable;

    const length: []u8 = try readBytes(file, allocator, 2);
    defer allocator.free(length);

    const app0: []u8 = try readBytes(file, allocator, hexSliceToInt(length));
    defer allocator.free(app0);

    // validate indentifier      =>           .J    .F    .I    .F    /0
    // if (!std.mem.eql(u8, &app0[0..5].*, &[_]u8{ 0x74, 0x70, 0x73, 0x70, 0x00 })) unreachable;
    std.debug.print("identifier: {any}\nversion {d}.{d}\nunits {d}\n", .{ app0[0..5].*, app0[5], app0[6], app0[7] });
    const density_x: []u8 = app0[8..10];
    const density_y: []u8 = app0[10..12];
    std.debug.print("density {d}x{d}\n", .{ hexSliceToInt(density_x), hexSliceToInt(density_y) });
    std.debug.print("thumbnail {d}x{d}\n", .{ app0[12], app0[13] });
}

fn validateSOI(file: File, allocator: std.mem.Allocator) !bool {
    const soi: []u8 = try readBytes(file, allocator, 2);
    defer allocator.free(soi);
    return (soi[0] == 0xFF) and (soi[1] == 0xD8);
}

fn readBytes(file: File, allocator: std.mem.Allocator, sz: usize) ![]u8 {
    const chunk: []u8 = try allocator.alloc(u8, sz);
    const ret: usize = try file.read(chunk);
    _ = ret;
    return chunk;
}

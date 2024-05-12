const std = @import("std");
const expect = std.testing.expect;
const File = std.fs.File;
const AutoHashMap = std.hash_map.AutoHashMap;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("cat.jpeg", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.print("mem leak", .{});
    }

    const segment_parser: type = *const fn (file: File, allocator: std.mem.Allocator) anyerror!void;
    var segment_map = AutoHashMap(u8, ?segment_parser).init(allocator);
    defer segment_map.deinit();

    // Start of Image
    try segment_map.put(0xD8, startOfImage);

    // Application 0
    try segment_map.put(0xE8, null);

    // Quantization Table
    try segment_map.put(0xDB, quantizationTable);

    // Start of Frame
    try segment_map.put(0xC0, null);

    // Huffman Table
    try segment_map.put(0xC4, null);

    // Start of Scan
    try segment_map.put(0xDA, null);

    // End of Image
    try segment_map.put(0xD9, null);

    var byte: [2]u8 = undefined;
    var Parser: segment_parser = undefined;

    _ = try file.read(&byte);
    std.debug.assert(byte[0] == 0xFF);

    Parser = segment_map.get(byte[1]).? orelse markerNotFound;
    _ = try Parser(file, allocator);

    // second etap
    _ = try file.read(&byte);
    std.debug.assert(byte[0] == 0xFF);

    Parser = segment_map.get(byte[1]).? orelse markerNotFound;
    _ = try Parser(file, allocator);
}

fn markerNotFound(file: File, allocator: std.mem.Allocator) anyerror!void {
    std.debug.print("WARNING: unknown marker found\n", .{});

    _ = file;
    _ = allocator;
}

fn startOfImage(file: File, allocator: std.mem.Allocator) anyerror!void {
    std.debug.print("INFO: Start of Image detected\n", .{});

    _ = file;
    _ = allocator;
}

fn quantizationTable(file: File, allocator: std.mem.Allocator) anyerror!void {
    _ = allocator;
    std.debug.print("INFO: Quantization Table detected\n", .{});

    var length: [2]u8 = undefined;
    _ = try file.read(&length);
    std.debug.print("INFO: length: {d}\n", .{hexSliceToInt(&length)});

    var destination: [1]u8 = undefined;
    _ = try file.read(&destination);
    std.debug.print("INFO: destination: {d}", .{destination[0]});

    if (destination[0] == 0) {
        std.debug.print(" (luminance)\n", .{});
    } else {
        std.debug.print(" (chrominance)\n", .{});
    }

    var table: [64]u8 = undefined;
    _ = try file.read(&table);
    std.debug.print("INFO: table: {any}\n", .{table});
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

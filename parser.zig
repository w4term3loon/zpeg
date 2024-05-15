const std = @import("std");
const expect = std.testing.expect;
const File = std.fs.File;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.hash_map.AutoHashMap;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("cat.jpeg", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: Allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.print("mem leak", .{});
    }

    const segment_parser: type = *const fn (file: File, allocator: Allocator) anyerror!void;
    var segment_map = AutoHashMap(u8, ?segment_parser).init(allocator);
    defer segment_map.deinit();

    try segment_map.put(0xD8, startOfImage);
    try segment_map.put(0xE0, app0);
    try segment_map.put(0xDB, quantizationTable);
    try segment_map.put(0xC0, startOfFrame);
    try segment_map.put(0xC4, huffmanTable);
    try segment_map.put(0xDA, startOfScan);
    try segment_map.put(0xD9, endOfImage);

    var marker: [2]u8 = undefined;
    var Parser: segment_parser = undefined;

    while (true) {
        _ = try file.read(&marker);
        std.debug.print("INFO: marker 0x{X} detected\n", .{marker[1]});
        Parser = segment_map.get(marker[1]).? orelse markerNotFound;
        try Parser(file, allocator);
        if (Parser == startOfScan) {
            std.debug.print("INFO: skipping image data TODO\n", .{});
            var lagger: [1]u8 = undefined;
            var leader: [1]u8 = undefined;
            while (!(lagger[0] == 0xFF and leader[0] != 0xD9)) {
                lagger = leader;
                _ = try file.read(&leader);
            }
            try endOfImage(file, allocator);
            break;
        }
    }
}

fn markerNotFound(file: File, allocator: Allocator) anyerror!void {
    std.debug.print("WARNING: unknown marker\n", .{});
    _ = .{ file, allocator };
}

fn startOfImage(file: File, allocator: Allocator) anyerror!void {
    std.debug.print("INFO: start of image\n", .{});
    _ = .{ file, allocator };
}

fn quantizationTable(file: File, allocator: Allocator) anyerror!void {
    std.debug.print("INFO: quantization table\n", .{});

    const length: u64 = try bytesAsDecimal(file, allocator, 2);
    std.debug.print("INFO: length: {d}\n", .{length});

    var destination: [1]u8 = undefined;
    _ = try file.read(&destination);
    std.debug.print("INFO: destination: {d}", .{destination[0]});

    // TODO: prettify
    if (destination[0] == 0) {
        std.debug.print(" (luminance)\n", .{});
    } else {
        std.debug.print(" (chrominance)\n", .{});
    }

    const body: u64 = length - destination.len - 2; //< length of length
    const table: []u8 = try allocator.alloc(u8, body);
    defer allocator.free(table);

    _ = try file.read(table);
    std.debug.print("INFO: table: {any}\n", .{table});
}

fn startOfFrame(file: File, allocator: Allocator) anyerror!void {
    std.debug.print("INFO: start of frame\n", .{});

    const length: u64 = try bytesAsDecimal(file, allocator, 2);
    std.debug.print("INFO: length {d}\n", .{length});

    const precision: u64 = try bytesAsDecimal(file, allocator, 1);
    std.debug.print("INFO: sample precision {d}\n", .{precision});

    const image_height: u64 = try bytesAsDecimal(file, allocator, 2);
    const image_width: u64 = try bytesAsDecimal(file, allocator, 2);
    std.debug.print("INFO: image dimensions {d}x{d}\n", .{ image_width, image_height });

    const components: u64 = try bytesAsDecimal(file, allocator, 1);
    std.debug.print("INFO: number of components {d}\n", .{components});

    for (0..components) |component| {
        const identifier: u64 = try bytesAsDecimal(file, allocator, 1);
        std.debug.print("INFO: component {d} id {d}\n", .{ component, identifier });

        // The 4 high-order bits specify the horizontal sampling for the component.
        // The 4 low-order bits specify the vertical sampling.
        // Either value can be 1, 2, 3, or 4 according to the standard.
        var sampling: [1]u8 = undefined;
        _ = try file.read(&sampling);
        const format = .{ component, sampling[0] & 0x0F, sampling[0] >> 4 };
        std.debug.print("INFO: component {d} sampling {d}x{d}(hxv)\n", format);

        const qtable_id: u64 = try bytesAsDecimal(file, allocator, 1);
        std.debug.print("INFO: component {d} qtable_id {d}\n", .{ component, qtable_id });
    }
}

fn huffmanTable(file: File, allocator: Allocator) anyerror!void {
    std.debug.print("INFO: huffman table\n", .{});

    const length: u64 = try bytesAsDecimal(file, allocator, 2);
    std.debug.print("INFO: length: {d}\n", .{length});

    const table: []u8 = try readBytes(file, allocator, length - 2);
    defer allocator.free(table);
    std.debug.print("INFO: table skipped: TODO\n", .{});
}

fn startOfScan(file: File, allocator: Allocator) anyerror!void {
    std.debug.print("INFO: start of scan\n", .{});

    const length: u64 = try bytesAsDecimal(file, allocator, 2);
    std.debug.print("INFO: length: {d}\n", .{length});

    const data: []u8 = try readBytes(file, allocator, length - 2);
    defer allocator.free(data);
    std.debug.print("INFO: data skipped: TODO\n", .{});
}

fn endOfImage(file: File, allocator: Allocator) anyerror!void {
    std.debug.print("INFO: end of image\n", .{});
    _ = .{ file, allocator };
}

fn app0(file: File, allocator: Allocator) anyerror!void {
    std.debug.print("INFO: application0\n", .{});

    const length: u64 = try bytesAsDecimal(file, allocator, 2);
    std.debug.print("INFO: length: {d}\n", .{length});

    const data: []u8 = try readBytes(file, allocator, length - 2);
    defer allocator.free(data);
    std.debug.print("INFO: skipping app0: TODO\n", .{});
}

fn bytesAsDecimal(file: File, allocator: Allocator, sz: usize) !u64 {
    const length: []u8 = try readBytes(file, allocator, sz);
    defer allocator.free(length);
    return hexSliceToInt(length);
}

fn hexSliceToInt(bytes: []u8) u64 {
    var ret: u64 = 0;
    for (bytes, 0..) |byte, i| {
        const iter: u8 = @as(u8, @intCast(bytes.len - 1 - i));
        ret += byte * std.math.pow(u64, 0xFF, iter);
    }
    return ret;
}

fn readBytes(file: File, allocator: Allocator, sz: usize) ![]u8 {
    const chunk: []u8 = try allocator.alloc(u8, sz);
    _ = try file.read(chunk);
    return chunk;
}

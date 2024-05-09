const std = @import("std");
const expect = @import("std").testing.expect;
const File = @import("std").fs.File;

fn readBytes(file: File, num: u32) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.print("mem leak", .{});
    }

    const chunk = try allocator.alloc(u8, num);
    defer allocator.free(chunk);

    const ret: usize = try file.read(chunk);
    std.debug.print("{any}b:{any}\n", .{ chunk, ret });
}

pub fn main() !void {
    const file = try std.fs.cwd().openFile("cat.jpeg", .{});
    defer file.close();

    _ = try readBytes(file, 8);
}

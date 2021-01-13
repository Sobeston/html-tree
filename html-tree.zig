const std = @import("std");
const Node = @This();

tag: ?[]u8 = null,
text: ?[]u8 = null,
child_nodes: std.ArrayListUnmanaged(Node) = std.ArrayListUnmanaged(Node){},
pub fn write(self: Node, writer: anytype) @TypeOf(writer).Error!void {
    if (self.tag) |t| try writer.print("<{s}>", .{t});
    for (self.child_nodes.items) |child| try child.write(writer);
    if (self.child_nodes.items.len == 0) {
        if (self.text) |text| try writer.print("{s}", .{text});
    }
    if (self.tag) |t| try writer.print("</{s}>", .{t});
}
pub fn addChild(self: *Node, allocator: *std.mem.Allocator, tag: ?[]const u8, text: ?[]const u8) !*Node {
    const new = Node{
        .tag = if (tag) |t| try allocator.dupe(u8, t) else null,
        .text = if (text) |t| try allocator.dupe(u8, t) else null,
    };
    try self.child_nodes.append(allocator, new);
    return &self.child_nodes.items[self.child_nodes.items.len - 1];
}
pub fn deinit(self: *Node, allocator: *std.mem.Allocator) void {
    for (self.child_nodes.items) |*child| child.deinit(allocator);
    self.child_nodes.deinit(allocator);
    if (self.text) |text| allocator.free(text);
    if (self.tag) |t| allocator.free(t);
    self.* = undefined;
}

test "usage" {
    const allocator = std.testing.allocator;
    var root = Node{};
    defer root.deinit(allocator);

    var html = try root.addChild(allocator, "html", null);
    var head = try html.addChild(allocator, "head", null);
    _ = try head.addChild(allocator, "title", "Hello, HTML!");
    var body = try html.addChild(allocator, "body", null);
    _ = try body.addChild(allocator, "h1", "Heading");
    _ = try body.addChild(allocator, "p", "Paragraph");

    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    try root.write(out.writer());

    std.testing.expectEqualStrings(
        \\<html><head><title>Hello, HTML!</title></head><body><h1>Heading</h1><p>Paragraph</p></body></html>
    ,
        out.items,
    );
}
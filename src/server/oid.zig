const std = @import("std");

pub const OIDGen = struct {
    rng: std.Random.Sfc64,

    pub fn init() OIDGen {
        const rng = std.Random.Sfc64.init(@as(u64, std.time.timestamp()));
        return .{ .rng = rng };
    }

    pub fn gen_id(self: *OIDGen) u128 {
        return self.rng.random().int(u128);
    }
};

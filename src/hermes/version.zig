pub const Version = packed struct {
    major: u8,
    minor: u8,
    patch: u8,
};

pub const version = Version{ .major = 0, .minor = 0, .patch = 1 };

/// Registers the host and window RPCs currently provided by the default
/// backend. New feature plugins can expose their own register() function
/// without changing the application entry point.
pub fn register(comptime Easy: type) *const fn (*Easy) anyerror!void {
    const CorePlugin = struct {
        fn bind(easy: *Easy) !void {
            try easy.bind(.increment);
            try easy.bind(.reset);
            try easy.bind(.getSystemInfo);
            try easy.bind(.getTimestamp);
            try easy.bind(.minimizeWindow);
            try easy.bind(.maximizeWindow);
            try easy.bind(.restoreWindow);
            try easy.bind(.enterFullscreen);
            try easy.bind(.exitFullscreen);
            try easy.bind(.closeWindow);
        }
    };

    return &CorePlugin.bind;
}

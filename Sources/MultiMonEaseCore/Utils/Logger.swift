import OSLog

public enum AppLogger {
    public static let subsystem = "com.meziantou.MultiMonEase"
    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let topology = Logger(subsystem: subsystem, category: "topology")
    public static let routing = Logger(subsystem: subsystem, category: "routing")
    public static let permissions = Logger(subsystem: subsystem, category: "permissions")
}

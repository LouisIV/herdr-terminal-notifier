import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("-help") || arguments.contains("--help") {
    printHelp()
    exit(0)
}

if arguments.contains("-version") || arguments.contains("--version") {
    print("HerdrNotify 0.2.0")
    exit(0)
}

if let removeIndex = arguments.firstIndex(of: "-remove") {
    let valueIndex = arguments.index(after: removeIndex)
    guard valueIndex < arguments.endIndex else {
        fputs("missing value for -remove\n", stderr)
        exit(1)
    }
    removeDeliveredNotifications(group: arguments[valueIndex])
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()

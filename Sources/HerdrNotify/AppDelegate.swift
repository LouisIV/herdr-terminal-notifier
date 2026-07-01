import AppKit
import Foundation

private struct NotificationRequest {
    var title = "Terminal"
    var subtitle = ""
    var message = ""
    var group = ""
    var sound = ""
    var execute = ""
    var open = ""
    var contentImage = ""
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    private let center = NSUserNotificationCenter.default

    func applicationDidFinishLaunching(_ notification: Notification) {
        center.delegate = self

        if let launchedNotification = notification.userInfo?[NSApplication.launchUserNotificationUserInfoKey] as? NSUserNotification {
            handleActivation(launchedNotification)
            NSApp.terminate(nil)
            return
        }

        do {
            let request = try parseArguments(Array(CommandLine.arguments.dropFirst()))
            deliver(request)
        } catch let error as UsageError {
            switch error {
            case .help:
                printHelp()
                NSApp.terminate(nil)
            case .version:
                print("HerdrNotify 0.2.0")
                NSApp.terminate(nil)
            case .message(let text):
                fputs("\(text)\n", stderr)
                NSApp.terminate(nil)
            }
        } catch {
            fputs("\(error)\n", stderr)
            NSApp.terminate(nil)
        }
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        true
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        handleActivation(notification)
        NSApp.terminate(nil)
    }

    private func deliver(_ request: NotificationRequest) {
        if !request.group.isEmpty {
            removeDeliveredNotifications(group: request.group)
        }

        let notification = NSUserNotification()
        notification.title = request.title
        notification.subtitle = request.subtitle
        notification.informativeText = request.message

        if !request.sound.isEmpty && request.sound != "none" {
            notification.soundName = request.sound == "default" ? NSUserNotificationDefaultSoundName : request.sound
        }

        if let image = image(at: request.contentImage) {
            notification.contentImage = image
        }

        var userInfo: [String: String] = [:]
        if !request.group.isEmpty { userInfo["group"] = request.group }
        if !request.execute.isEmpty { userInfo["execute"] = request.execute }
        if !request.open.isEmpty { userInfo["open"] = request.open }
        notification.userInfo = userInfo

        center.deliver(notification)
        NSApp.terminate(nil)
    }

    private func handleActivation(_ notification: NSUserNotification) {
        guard notification.activationType == .contentsClicked || notification.activationType == .actionButtonClicked else {
            return
        }

        if let command = notification.userInfo?["execute"] as? String, !command.isEmpty {
            runShell(command)
        }

        if let rawURL = notification.userInfo?["open"] as? String,
           let url = URL(string: rawURL),
           !rawURL.isEmpty {
            NSWorkspace.shared.open(url)
        }
    }

    private func image(at path: String) -> NSImage? {
        guard !path.isEmpty else { return nil }
        if let url = URL(string: path), url.scheme != nil {
            return NSImage(contentsOf: url)
        }
        return NSImage(contentsOfFile: path)
    }

    private func runShell(_ command: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        try? task.run()
    }
}

private enum UsageError: Error {
    case help
    case version
    case message(String)
}

private func parseArguments(_ arguments: [String]) throws -> NotificationRequest {
    if arguments.isEmpty {
        throw UsageError.help
    }

    var request = NotificationRequest()
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]

        func value(after option: String) throws -> String {
            let valueIndex = index + 1
            guard valueIndex < arguments.count else {
                throw UsageError.message("missing value for \(option)")
            }
            index += 2
            return arguments[valueIndex]
        }

        switch argument {
        case "-help", "--help":
            throw UsageError.help
        case "-version", "--version":
            throw UsageError.version
        case "-title":
            request.title = try value(after: argument)
        case "-subtitle":
            request.subtitle = try value(after: argument)
        case "-message":
            request.message = try value(after: argument)
        case "-group":
            request.group = try value(after: argument)
        case "-sound":
            request.sound = try value(after: argument)
        case "-execute":
            request.execute = try value(after: argument)
        case "-open":
            request.open = try value(after: argument)
        case "-contentImage":
            request.contentImage = try value(after: argument)
        case "-appIcon":
            _ = try value(after: argument)
        case "-remove":
            let group = try value(after: argument)
            removeDeliveredNotifications(group: group)
            NSApp.terminate(nil)
        case "-ignoreDnD":
            index += 1
        default:
            throw UsageError.message("unknown option: \(argument)")
        }
    }

    if request.message.isEmpty {
        throw UsageError.message("missing required -message value")
    }

    return request
}

func removeDeliveredNotifications(group: String) {
    let center = NSUserNotificationCenter.default
    if group == "ALL" {
        center.removeAllDeliveredNotifications()
        return
    }

    center.deliveredNotifications
        .filter { $0.userInfo?["group"] as? String == group }
        .forEach { center.removeDeliveredNotification($0) }
}

func printHelp() {
    print("""
    Usage: terminal-notifier -message VALUE [options]

    Required:
      -message VALUE

    Supported options:
      -title VALUE
      -subtitle VALUE
      -sound NAME
      -group ID
      -contentImage PATH_OR_URL
      -execute COMMAND
      -open URL
      -remove ID|ALL
      -help
      -version
    """)
}

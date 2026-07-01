import ProjectDescription

let project = Project(
    name: "HerdrTerminalNotifier",
    organizationName: "dot",
    targets: [
        .target(
            name: "HerdrNotify",
            destinations: .macOS,
            product: .app,
            bundleId: "codes.dot.herdr-notify",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .file(path: "Sources/HerdrNotify/Info.plist"),
            sources: ["Sources/HerdrNotify/**/*.swift"],
            resources: ["Sources/HerdrNotify/Resources/**"],
            settings: .settings(base: [
                "CODE_SIGN_IDENTITY": "-",
                "CODE_SIGN_STYLE": "Manual",
                "EXECUTABLE_NAME": "terminal-notifier",
                "PRODUCT_NAME": "HerdrNotify",
                "SWIFT_VERSION": "5.0",
            ])
        )
    ]
)

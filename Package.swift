// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuDoom",
    platforms: [.macOS(.v12)],
    targets: [
        // The Doom engine (doomgeneric, GPLv2) plus the menu bar glue in doomgeneric_menubar.c.
        .target(
            name: "DoomGeneric",
            path: "Sources/DoomGeneric",
            exclude: ["LICENSE"],
            publicHeadersPath: "include",
            cSettings: [
                .define("NORMALUNIX"),
                .define("_DEFAULT_SOURCE"),
                // Doom's 1993 C has plenty of warnings on a modern compiler. Hide them.
                .unsafeFlags(["-w"])
            ]
        ),
        // The menu bar app.
        .executableTarget(
            name: "MenuDoom",
            dependencies: ["DoomGeneric"],
            path: "Sources/MenuDoom"
        )
    ]
)

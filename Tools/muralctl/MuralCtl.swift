import ArgumentParser
import Foundation

@main
struct MuralCtl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "muralctl",
        abstract: "Control Mural from the command line.",
        subcommands: [
            SetCmd.self,
            CloseCmd.self,
            PauseCmd.self,
            ResumeCmd.self,
            StatusCmd.self,
            SetPropCmd.self,
            ImportCmd.self
        ]
    )
}

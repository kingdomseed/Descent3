import Darwin
import Foundation

private let usage = "usage: D3Import --contract 1 --source <directory> --staging <directory> --destination <directory> --scope <scope> --report <json-path>\n"

do {
    blockD3ImportCancellationSignals()
    let arguments = try D3ImportArguments.parse(CommandLine.arguments)
    let report = try runD3Import(
        arguments,
        cancellationCheck: pendingD3ImportCancellationSignal
    )
    print("promoted \(report.levelKey) with \(report.counts.usedRooms) rooms")
} catch D3ImportOperationError.invalidArguments {
    fputs(usage, stderr)
    exit(EX_USAGE)
} catch D3ImportOperationError.cancelled(let signal) {
    exit(128 + signal)
} catch {
    fputs("D3Import: \(error)\n", stderr)
    exit(EX_DATAERR)
}

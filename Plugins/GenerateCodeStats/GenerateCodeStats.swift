import Foundation
import PackagePlugin

@main
struct GenerateCodeStats: CommandPlugin {
    let fileManager = FileManager.default
    let processor = FileStatsProcessor()

    func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        let targets = try parseTargets(context: context, arguments: arguments)
        let dirs = targets.isEmpty ? [context.package.directory] : targets.map(\.directory)

        try generateCodeStats(dirs: dirs)

        let output = context.package.directory.appending(subpath: Const.outputFileName)
        try processor.stats.description.write(
            to: URL(fileURLWithPath: output.string),
            atomically: true,
            encoding: .utf8
        )
    }

    private func parseTargets(
        context: PluginContext,
        arguments: [String]
    ) throws -> [Target] {
        arguments
            .enumerated()
            .filter { $0.element == "--target" }
            .map { arguments[$0.offset + 1] }
            .compactMap { try? context.package.targets(named: [$0]) }
            .flatMap { $0 }
    }

    private func generateCodeStats(dirs: [Path]) throws {
        for dir in dirs {
            guard let files = fileManager.enumerator(atPath: dir.string) else { continue }

            for case let path as String in files {
                let fullpath = dir.appending([path])
                var isDirectory: ObjCBool = false

                guard
                    fullpath.extension == "swift",
                    fileManager.fileExists(atPath: fullpath.string, isDirectory: &isDirectory),
                    !isDirectory.boolValue
                else { continue }

                try processor.processFile(at: fullpath)
            }
        }
    }
}

extension GenerateCodeStats {
    enum Const {
        fileprivate static let outputFileName = "CodeStats.md"
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension GenerateCodeStats: XcodeCommandPlugin {
    func performCommand(
        context: XcodeProjectPlugin.XcodePluginContext,
        arguments: [String]
    ) throws {
        try generateCodeStats(dirs: [context.xcodeProject.directory])

        let output = context.xcodeProject.directory.appending(subpath: Const.outputFileName)
        try processor.stats.description.write(
            to: URL(fileURLWithPath: output.string),
            atomically: true,
            encoding: .utf8
        )
    }
}
#endif

final class FileStatsProcessor {
    private(set) var stats = CodeStats()

    private let definitionsRegex: NSRegularExpression = {
        let pattern = #"\b(?<name>protocol|class|struct|enum)\b"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    private let newlinesRegex: NSRegularExpression = {
        return try! NSRegularExpression(pattern: #"$"#, options: [.anchorsMatchLines])
    }()

    func processFile(at path: Path) throws {
        let text = try String(contentsOfFile: path.string)
        let textRange = NSRange(text.startIndex..<text.endIndex, in: text)

        stats.numberOfFiles += 1
        stats.numberOfLines += newlinesRegex.matches(in: text, range: textRange).count

        definitionsRegex.enumerateMatches(in: text, range: textRange) { match, _, _ in
            guard let nsRange = match?.range(withName: "name"),
                  let range = Range(nsRange, in: text)
            else { return }

            switch text[range.lowerBound] {
            case "p": stats.numberOfProtocols += 1
            case "c": stats.numberOfClasses += 1
            case "s": stats.numberOfStructs += 1
            case "e": stats.numberOfEnums += 1
            default: break
            }
        }
    }
}

struct CodeStats: CustomStringConvertible {
    var numberOfFiles: Int = 0
    var numberOfLines: Int = 0
    var numberOfClasses: Int = 0
    var numberOfStructs: Int = 0
    var numberOfEnums: Int = 0
    var numberOfProtocols: Int = 0

    var description: String {
        return [
            "## Code statistics\n",
            "Number of files:     \(fmt(numberOfFiles))",
            "Number of lines:     \(fmt(numberOfLines))",
            "Number of classes:   \(fmt(numberOfClasses))",
            "Number of structs:   \(fmt(numberOfStructs))",
            "Number of enums:     \(fmt(numberOfEnums))",
            "Number of protocols: \(fmt(numberOfProtocols))"
        ].joined(separator: "\n")
    }

    private func fmt(_ i: Int) -> String {
        String(format: "%8d", i)
    }
}

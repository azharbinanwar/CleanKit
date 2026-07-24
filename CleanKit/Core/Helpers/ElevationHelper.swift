import Foundation

enum ElevationError: LocalizedError {
    case userCancelled
    case scriptError(String)

    var errorDescription: String? {
        switch self {
        case .userCancelled: return "Password prompt was cancelled"
        case .scriptError(let m): return m
        }
    }
}

struct ElevationHelper {
    @MainActor
    static func runWithPrivileges(_ command: String) throws {
        // Escape for embedding inside an AppleScript string literal
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScriptSource = "do shell script \"\(escaped)\" with administrator privileges"

        guard let script = NSAppleScript(source: appleScriptSource) else {
            throw ElevationError.scriptError("Could not create script")
        }

        var error: NSDictionary?
        script.executeAndReturnError(&error)

        if let err = error {
            if err["NSAppleScriptErrorNumber"] as? Int == -128 {
                throw ElevationError.userCancelled
            }
            let message = err[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw ElevationError.scriptError(message)
        }
    }
}

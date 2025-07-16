import Foundation

enum CoreUtil {

    static let deviceIsCompromised: Bool = {
#if targetEnvironment(simulator)
        return false
#endif

        let file = fopen("/bin/bash", "r")
        if let file {
            fclose(file)
            return true
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: "/bin/bash") {
            return true
        }

        let string = "sosi jopu"
        let jailbreakFilePath = "/private/jailbreak.txt"
        do {
            try string.write(toFile: jailbreakFilePath, atomically: true, encoding: .utf8)
            try fileManager.removeItem(atPath: jailbreakFilePath)
            return true
        } catch {
            return false
        }
    }()

}

import Foundation

public extension RemoteDataModels {
    
    struct Report: Codable {

        public enum Issue: String, Codable {
            case name
            case username
            case userContent
        }

        public enum SubIssue: String, Codable {
            case iDontLikeIt = "I don't like it"
            case childAbuse = "Child abuse"
            case violence = "Violence"
            case illegalGoods = "Illegal goods"
            case personalData = "Personal data"
            case terrorism = "Terrorism"
            case scamOrSpam = "Scam or spam"
            case copyright = "Copyright"
            case other = "Other"
            case notIllegalButItMustBeTakenDown = "It's not illegal, but it must be taken down"
        }

        public let issue: Issue

        public let subIssue: SubIssue

        public let timestamp: Date

        public let reporterId: String

        public let id: String

        public init(issue: Issue,
                    subIssue: SubIssue,
                    timestamp: Date,
                    reporterId: String,
                    id: String) {
            self.issue = issue
            self.subIssue = subIssue
            self.timestamp = timestamp
            self.reporterId = reporterId
            self.id = id
        }

    }

}

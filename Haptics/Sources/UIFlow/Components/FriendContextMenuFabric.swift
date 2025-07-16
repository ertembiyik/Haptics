import UIKit
import Resources
import RemoteDataModels

enum FriendContextMenuFabric {

    static func contextMenu(blockDidTapHandler: @escaping () -> Void,
                            reportDidTapHandler: @escaping (RemoteDataModels.Report.Issue,
                                                            RemoteDataModels.Report.SubIssue) -> Void,
                            removeDidTapHandler: @escaping () -> Void) -> UIMenu {
        let blockAction = UIAction(title: String.res.friendContextMenuActionsBlock,
                                   image: UIImage.res.handRaisedFill,
                                   attributes: .destructive) { _ in
            blockDidTapHandler()
        }

        let reportActions: (RemoteDataModels.Report.Issue) -> [UIAction] = { issue in
            return [
                (RemoteDataModels.Report.SubIssue.iDontLikeIt,
                 String.res.friendContextMenuActionsReportIDontLikeIt),
                (RemoteDataModels.Report.SubIssue.childAbuse,
                String.res.friendContextMenuActionsReportChildAbuse),
                (RemoteDataModels.Report.SubIssue.violence,
                String.res.friendContextMenuActionsReportViolence),
                (RemoteDataModels.Report.SubIssue.illegalGoods,
                String.res.friendContextMenuActionsReportIllegalGoods),
                (RemoteDataModels.Report.SubIssue.personalData,
                 String.res.friendContextMenuActionsReportPersonalData),
                (RemoteDataModels.Report.SubIssue.terrorism,
                String.res.friendContextMenuActionsReportTerrorism),
                (RemoteDataModels.Report.SubIssue.scamOrSpam,
                String.res.friendContextMenuActionsReportScamOrSpam),
                (RemoteDataModels.Report.SubIssue.copyright,
                String.res.friendContextMenuActionsReportCopyright),
                (RemoteDataModels.Report.SubIssue.other,
                String.res.friendContextMenuActionsReportOther),
                (RemoteDataModels.Report.SubIssue.notIllegalButItMustBeTakenDown,
                String.res.friendContextMenuActionsReportNotIllegalButItMustBeTakenDown)
            ].map { subIssue, title in
                UIAction(title: title,
                         image: nil) { _ in
                    reportDidTapHandler(issue, subIssue)
                }
            }
        }

        let reportIssueMenus = [
            (RemoteDataModels.Report.Issue.name,
             String.res.friendContextMenuActionsReportName),
            (RemoteDataModels.Report.Issue.username,
             String.res.friendContextMenuActionsReportUsername),
            (RemoteDataModels.Report.Issue.userContent,
             String.res.friendContextMenuActionsReportUserContent)
        ].map { issue, title in
            UIMenu(title: title, children: reportActions(issue))
        }

        let reportMenu = UIMenu(title: String.res.friendContextMenuActionsReport,
                                image: UIImage.res.exclamationmarkCircle,
                                options: .destructive,
                                children: reportIssueMenus)

        let topMenu = UIMenu(options: .displayInline, children: [blockAction, reportMenu])

        let removeAction = UIAction(title: String.res.friendContextMenuActionsRemove,
                                    image: UIImage.res.minusCircle,
                                    attributes: .destructive) { _ in
            removeDidTapHandler()
        }

        return UIMenu(children: [topMenu, removeAction])
    }

}

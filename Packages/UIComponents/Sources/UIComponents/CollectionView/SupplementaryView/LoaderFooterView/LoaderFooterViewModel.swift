import Foundation
import Combine

public protocol LoaderFooterViewModel: BindableSupplementaryViewModel, AnyObject {

    var stateDataPublisher: AnyPublisher<LoaderFooterStateData, Never> { get }

    var stateData: LoaderFooterStateData { get }
    
}

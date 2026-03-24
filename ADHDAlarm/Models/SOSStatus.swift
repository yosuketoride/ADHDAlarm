import Foundation

enum SOSStatus: Equatable {
    case idle
    case sending
    case sent
    case failed(String)
}

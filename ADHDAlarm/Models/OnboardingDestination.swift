import Foundation

/// オンボーディング NavigationStack の遷移先
enum OnboardingDestination: Hashable {
    case personWelcome
    case permissionsCTA
    case owlNaming
    case magicDemoWarning
    case magicDemo
    case widgetGuide
}

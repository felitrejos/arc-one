import Foundation

protocol BiometricsStoring {
    var biometricsEnabled: Bool { get set }
}

struct BiometricsStore: BiometricsStoring {
    private let key = "biometricsEnabled"

    var biometricsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

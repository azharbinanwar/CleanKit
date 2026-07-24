import Foundation
import Observation

@MainActor
final class ServiceLocator {
    static let shared = ServiceLocator()
    
    private var services: [String: Any] = [:]
    
    private init() {}
    
    func register<T>(_ service: T) {
        let key = String(describing: T.self)
        services[key] = service
    }
    
    func resolve<T>() -> T {
        let key = String(describing: T.self)
        guard let service = services[key] as? T else {
            fatalError("No service registered for \(key)")
        }
        return service
    }
}

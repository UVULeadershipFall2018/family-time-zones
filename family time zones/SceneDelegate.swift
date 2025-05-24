import UIKit
import SwiftUI
import CoreLocation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents
        let contentView = ContentView(viewModel: ContactViewModel())
        
        // Use a UIHostingController as window root view controller
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        // Handle any URL contexts that were provided at launch
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(url: urlContext.url)
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Resume location updates when the app becomes active
        LocationManager.shared.startLocationUpdates()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // We'll keep location updates running in the background
        // But we could adjust precision or frequency here
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // App entered background - ensure location updates can continue
        let locationManager = LocationManager.shared
        
        // Ensure background location updates are properly configured
        if locationManager.permissionStatus == .authorizedAlways {
            // Continue background updates with significant change monitoring
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                print("App entered background - continuing significant location monitoring")
            }
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        
        handleIncomingURL(url: url)
    }
    
    private func handleIncomingURL(url: URL) {
        // Handle location sharing invitation deep links
        if url.scheme == "familytimezones" {
            // Get the shared LocationManager instance
            let locationManager = (UIApplication.shared.windows.first?.rootViewController as? UIHostingController<ContentView>)?.rootView.viewModel.locationManager
            
            if locationManager?.handleInvitationDeepLink(url: url) == true {
                // Successfully handled invitation
                print("Successfully processed location sharing invitation")
                
                // Notify the app that a location update has occurred
                NotificationCenter.default.post(name: NSNotification.Name("LocationSharingInvitationAccepted"), object: nil)
            }
        }
    }
}
 
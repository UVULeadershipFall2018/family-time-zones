import UIKit
import SwiftUI

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
 
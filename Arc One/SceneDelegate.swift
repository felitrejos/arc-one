//
//  SceneDelegate.swift
//  Arc One
//
//  Created by Felipe Trejos on 28/10/25.
//

import UIKit
import FirebaseAuth
import GoogleSignIn
import LocalAuthentication

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private let biometricsEnabledKey = "biometricsEnabled"

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        _ = GIDSignIn.sharedInstance.handle(url)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let window = UIWindow(windowScene: windowScene)

        if Auth.auth().currentUser != nil {
            if shouldLockWithBiometrics() {
                authenticate { success in
                    if success {
                        window.rootViewController = storyboard.instantiateViewController(withIdentifier: "TabController")
                        window.makeKeyAndVisible()
                    }
                }
            } else {
                window.rootViewController = storyboard.instantiateViewController(withIdentifier: "TabController")
                window.makeKeyAndVisible()
            }
        } else {
            window.rootViewController = storyboard.instantiateViewController(withIdentifier: "LoginController")
            window.makeKeyAndVisible()
        }

        self.window = window
    }

    private func shouldLockWithBiometrics() -> Bool {
        guard UserDefaults.standard.bool(forKey: biometricsEnabledKey) else { return false }

        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    private func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock Arc One"
        ) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}

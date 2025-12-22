//
//  ProfileService.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import UIKit
import FirebaseAuth

final class ProfileService {

    struct ProfileState {
        let name: String
        let email: String
        let avatar: UIImage
    }

    private var authHandle: AuthStateDidChangeListenerHandle?

    func startListening(onChange: @escaping (ProfileState) -> Void) {
        stopListening()

        authHandle = Auth.auth().addStateDidChangeListener { _, _ in
            self.refreshUserFromServer { state in
                onChange(state)
            }
        }

        // initial
        refreshUserFromServer { state in
            onChange(state)
        }
    }

    func stopListening() {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        authHandle = nil
    }

    func refreshUserFromServer(completion: @escaping (ProfileState) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(ProfileState(
                name: "",
                email: "",
                avatar: UIImage(systemName: "person.crop.circle.fill")!
            ))
            return
        }

        user.reload { _ in
            self.readUserState(completion: completion)
        }
    }

    func readUserState(completion: @escaping (ProfileState) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(ProfileState(
                name: "",
                email: "",
                avatar: UIImage(systemName: "person.crop.circle.fill")!
            ))
            return
        }

        let name = user.displayName ?? ""
        let email = user.email ?? ""

        if let url = user.photoURL {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                let avatar = data.flatMap(UIImage.init(data:)) ?? UIImage(systemName: "person.crop.circle.fill")!
                DispatchQueue.main.async {
                    completion(ProfileState(name: name, email: email, avatar: avatar))
                }
            }.resume()
        } else {
            completion(ProfileState(
                name: name,
                email: email,
                avatar: UIImage(systemName: "person.crop.circle.fill")!
            ))
        }
    }

    func loadInformationItems(completion: @escaping ([(title: String, value: String)]) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion([("Status", "Not logged in")])
            return
        }

        user.reload { _ in
            let providers = user.providerData
                .map { Self.prettyProviderName($0.providerID) }
                .joined(separator: ", ")

            let creation = user.metadata.creationDate.map { Self.formatDate($0) } ?? "—"
            let lastSignIn = user.metadata.lastSignInDate.map { Self.formatDate($0) } ?? "—"

            let items: [(String, String)] = [
                ("Name", user.displayName ?? "—"),
                ("Email", user.email ?? "—"),
                ("Email verified", user.isEmailVerified ? "Yes" : "No"),
                ("Phone", user.phoneNumber ?? "—"),
                ("Login method", providers.isEmpty ? "—" : providers),
                ("Account created", creation),
                ("Last sign-in", lastSignIn)
            ]

            DispatchQueue.main.async { completion(items) }
        }
    }

    private static func prettyProviderName(_ providerID: String) -> String {
        switch providerID {
        case "google.com": return "Google"
        case "password": return "Email & Password"
        default: return providerID
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

//
//  FirebaseManager.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import FirebaseAuth
import FirebaseFirestore

enum FirebaseManager {

    static var db: Firestore {
        Firestore.firestore()
    }

    static var auth: Auth {
        Auth.auth()
    }

    static var uid: String? {
        auth.currentUser?.uid
    }
}

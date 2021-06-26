//
// Created by Andreas Bauer on 22.01.21.
//

import Apodini
import ApodiniExtension


struct AuthenticatedUserHandler: Handler {
    func handle() -> User {
        User(id: 9)
    }
}

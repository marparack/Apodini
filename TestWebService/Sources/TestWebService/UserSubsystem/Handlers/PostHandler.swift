//
// Created by Andreas Bauer on 22.01.21.
//

import Foundation
import Apodini
import ApodiniExtension

struct PostHandler: Handler {
    @Binding var userId: Int
    @Binding var postId: UUID

    func handle() -> Post {
        Post(id: postId, title: "Example Title")
    }
}

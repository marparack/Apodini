//
// This source file is part of the Apodini open source project
// 
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Apodini


struct GreetComponent: Component {
    let greeterRelationship: Relationship

    var content: some Component {
        Group("greet") {
            TraditionalGreeter()
                .response(EmojiTransformer())
                .destination(of: greeterRelationship)
                .identified(by: "greetMe")
                .endpointName("greetMe")
        }
    }
}

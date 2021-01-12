//
//  TestWebService.swift
//
//
//  Created by Paul Schmiedmayer on 7/6/20.
//

import Apodini

class ClassString: Codable {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

struct TestWebService: Apodini.WebService {
    struct PrintGuard: SyncGuard {
        private let message: String

        init(_ message: String = "PrintGuard 👋") {
            self.message = message
        }
        

        func check() {
            print(message)
        }
    }
    
    struct EmojiMediator: ResponseTransformer {
        private let emojis: String
        
        
        init(emojis: String = "✅") {
            self.emojis = emojis
        }
        
        
        func transform(response: String) -> String {
            "\(emojis) \(response) \(emojis)"
        }
    }
    

    struct TraditionalGreeter: Handler {
        @Parameter var name: ClassString = ClassString(name: "Apodini")
        @Parameter var overwrite: Bool = false

        func handle() -> String {
            if overwrite {
                self.name.name = "Max"
            }
            return "Hi, \(name.name)!"
        }
    }

    struct User: Codable {
        var id: Int
    }

    struct UserHandler: Handler {
        @Parameter var userId: Int

        func handle() -> User {
            User(id: userId)
        }
    }

    @PathParameter var userId: Int
    
    var content: some Component {
        Text("Hello World! 👋")
            .response(EmojiMediator(emojis: "🎉"))
            .response(EmojiMediator())
            .guard(PrintGuard())
        Group("swift") {
            Text("Hello Swift! 💻")
                .response(EmojiMediator())
                .guard(PrintGuard())
            Group("5", "3") {
                Text("Hello Swift 5! 💻")
            }
        }.guard(PrintGuard("Someone is accessing Swift 😎!!"))
        Group("greet") {
            TraditionalGreeter()
                .serviceName("GreetService")
                .rpcName("greetMe")
                .response(EmojiMediator())
        }
        Group("user", $userId) {
            UserHandler(userId: $userId)
                .guard(PrintGuard())
        }
    }
}

try TestWebService.main()

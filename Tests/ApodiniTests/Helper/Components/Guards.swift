//
// Created by Andreas Bauer on 25.12.20.
//

@testable import Apodini
@testable import ApodiniExtension

struct PrintGuard: SyncGuard {
    func check() {
        print("PrintGuard check executed")
    }
}

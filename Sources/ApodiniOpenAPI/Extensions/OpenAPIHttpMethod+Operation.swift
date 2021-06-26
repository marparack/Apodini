//
//  Created by Lorena Schlesinger on 15.11.20.
//

import Foundation
import Apodini
import ApodiniExtension
import OpenAPIKit

extension OpenAPIKit.OpenAPI.HttpMethod {
    init(_ operation: ApodiniExtension.Operation) {
        switch operation {
        case .read:
            self = .get
        case .create:
            self = .post
        case .update:
            self = .put
        case .delete:
            self = .delete
        }
    }
}

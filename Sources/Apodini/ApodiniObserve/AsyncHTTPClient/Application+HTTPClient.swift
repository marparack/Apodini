//
//  Application+HTTPClient.swift
//  
//
//  Created by Philipp Zagar on 26.06.21.
//

import AsyncHTTPClient

extension Application {
    /// You can use the [AsyncHTTPClient](https://github.com/swift-server/async-http-client) to make HTTP requests in `Handlers` using the Environment: `@Environment(\.httpClient) var httpClient: HTTPClient`
    /// For more information about the [AsyncHTTPClient check out the documentation fround in the AsyncHTTPClient repository at https://github.com/swift-server/async-http-client](https://github.com/swift-server/async-http-client).
    public internal(set) var httpClient: HTTPClient {
        get {
            guard let httpClient = self.storage[HTTPClientStorageKey.self] else {
                HTTPClientConfiguration()
                    .configure(self)
                return self.httpClient
            }
            
            return httpClient
        }
        set {
            self.storage[HTTPClientStorageKey.self] = newValue
        }
    }
}

private struct HTTPClientStorageKey: StorageKey {
    typealias Value = HTTPClient
}

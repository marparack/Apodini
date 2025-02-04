//
// This source file is part of the Apodini open source project
// 
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Apodini

private struct TestComponent: Component {
    var content: some Component {
        Text("Hello World!")
    }

    var metadata: Metadata {
        TestVoidComponentOnlyMetadata()

        ComponentVoids {
            TestVoidComponentMetadata()

            // error: No exact matches in call to static method 'buildExpression'
            TestVoidComponentOnlyMetadata()
        }

        ComponentOnlyVoids {
            TestVoidComponentOnlyMetadata()

            // error: No exact matches in call to static method 'buildExpression'
            TestVoidComponentMetadata()
        }

        // error: Argument type 'AnyHandlerMetadata' does not conform to expected type 'AnyComponentOnlyMetadata'
        HandlerVoids {
            TestVoidHandlerMetadata()
        }

        // error: no exact matches in call to static method 'buildExpression'
        ContentVoids {
            TestVoidContentMetadata()
        }
    }
}

private struct TestComponent2: Component {
    var content: some Component {
        Text("Hello World!")
    }

    var metadata: Metadata {
        TestVoidComponentOnlyMetadata()

        // error: Argument type 'AnyWebServiceMetadata' does not conform to expected type 'AnyComponentOnlyMetadata'
        WebServiceVoids {
            TestVoidWebServiceMetadata()
        }
    }
}

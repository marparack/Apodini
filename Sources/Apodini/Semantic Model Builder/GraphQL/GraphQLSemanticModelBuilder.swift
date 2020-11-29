//
//  GraphQLSemanticModelBuilder.swift
//
//
//  Created by Paul Schmiedmayer on 6/26/20.
//

//import GraphZahl
//import GraphZahlVaporSupport

import Vapor
import Graphiti
import NIO


//struct RESTPathBuilder: PathBuilder {
//    private var pathComponents: [Vapor.PathComponent] = []
//
//    fileprivate var pathDescription: String {
//        pathComponents.map { pathComponent in
//            pathComponent.description
//        }.joined(separator: "/")
//    }
//
//    init(_ pathComponents: [PathComponent]) {
//        for pathComponent in pathComponents {
//            if let pathComponent = pathComponent as? _PathComponent {
//                pathComponent.append(to: &self)
//            }
//        }
//    }
//
//    mutating func append(_ string: String) {
//        let pathComponent = string.lowercased()
//        pathComponents.append(.constant(pathComponent))
//    }
//
//    mutating func append<T>(_ identifiier: Identifier<T>) where T: Identifiable {
//        let pathComponent = identifiier.identifier
//        pathComponents.append(.parameter(pathComponent))
//    }
//
//    func routesBuilder(_ app: Vapor.Application) -> Vapor.RoutesBuilder {
//        app.routes.grouped(pathComponents)
//    }
//}


//final class GraphQLMiddleWare : Middleware {
//    func respond(to request: Vapor.Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
//        print(request.url.path)
//        let response = request.redirect(to: "Hi", type: .permanent)
//        return request.eventLoop.makeSucceededFuture(response)
//    }
//
//    //
//    //    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
//    //        print(request.wrappedValue.url.path)
//    //        let response = request.wrappedValue.redirect(to: "Hi", type: .permanent)
//    //        return request.wrappedValue.eventLoop.makeSucceededFuture(response)
//    //    }
//}


//struct GraphQLPathBuilder : PathBuilder {
//    private var pathComponents: [Vapor.PathComponent] = ["graphql"]
//
//    init(_ pathComponents: [PathComponent]) {
//        for pathComponent in pathComponents {
//            if let pathComponent = pathComponent as? _PathComponent {
//                pathComponent.append(to: &self)
//            }
//        }
//    }
//    mutating func append(_ string: String) {
//        let pathComponent = string.lowercased()
//        pathComponents.append(.constant(pathComponent))
//    }
//
//
//    mutating func append<T>(_ identifiier: Identifier<T>) where T: Identifiable {
//        let pathComponent = identifiier.identifier
//        pathComponents.append(.parameter(pathComponent))
//    }
//
//    func routesBuilder(_ app: Vapor.Application) -> Vapor.RoutesBuilder {
//        app.routes.grouped(pathComponents)
//    }
//
//}

//final class ExtendPathMiddleware: Middleware {
//
//    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
//        if !request.url.path.hasSuffix("/") {
//            let response = request.redirect(to: request.url.path + "/", type: .permanent)
//            return request.eventLoop.makeSucceededFuture(response)
//        }
//        return next.respond(to: request)
//    }
//}

//func createRequestHandler<C: Component>(withComponent component: C)
//    -> (Vapor.Request) -> EventLoopFuture<Vapor.Response>
//{
//
//}


struct Message: Codable {
    let content: String
}

struct ContextGQL {
    func message() -> Message {
        Message(content: "Hello, world!")
    }
}

struct Resolver {
    func message(context: ContextGQL, arguments: NoArguments) -> Message {
        context.message()
    }
}

struct MessageAPI: Graphiti.API {
    let resolver: Resolver
    let schema: Schema<Resolver, ContextGQL>

    init(resolver: Resolver) throws {
        self.resolver = resolver

        self.schema = try Schema<Resolver, ContextGQL> {
            Type(Message.self) {
                Graphiti.Field("content", at: \.content)
            }

            Graphiti.Query {
                Graphiti.Field("message", at: Resolver.message)
            }
        }
    }
}


class AnswerType {
    private var path = "MY PATH"

    init() {
    }

    init(_ path: String) {
        self.path = path
    }

    func handle(_ req: Vapor.Request) -> String {
        path
    }
}

class Answer {
    private var functionalities: [String: AnswerType] = [:]

    init() {
        do {
            let resolver = Resolver()
            let context = ContextGQL()
            let api = try MessageAPI(resolver: resolver)
            let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

            defer {
                try? group.syncShutdownGracefully()
            }

            api.execute(
                    request: "{ message { content } }",
                    context: context,
                    on: group
            ).whenSuccess { result in
                print(result)
            }
        } catch {
            print("Error in the api creation")
        }

    }

    func answer(_ req: Vapor.Request) -> String {
        let _headers = req.headers
        let _desc = req.description
        print("HEADERS", req.headers)
        print("BODY", req.body.data as? [String: AnyObject])
        print("DESC", req.description)
        let body = req.body.string ?? "{}"
        let data = body.data(using: .utf8)!
        print("BODY2", body)
        print("DATA: ", data)
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: AnyObject] {

                if let request = jsonArray["query"] as? String {
                    print("Request is :", request)
                    return (functionalities[request] ?? AnswerType()).handle(req)
                } else {
                    print("Couldn't do it \(jsonArray["query"])")
                }
            } else {
                print("bad json")
                return "Couldn't Parse GraphQL Query"
            }
        } catch let error as NSError {
            print(error)
            return "Couldn't Parse GraphQL Query"
        }
        print(functionalities)
        return (functionalities[req.body.string ?? ""] ?? AnswerType()).handle(req)
    }

    func update_functionality(_ path: String, _ answer: AnswerType) {
        functionalities[path] = answer
    }
}

class GraphQLSemanticModelBuilder: SemanticModelBuilder {
    private let answer = Answer()

    override init(_ app: Application) {
        // Start  the server
        app.post("graphql", use: answer.answer)
        super.init(app)
    }

    override func register<C: Component>(component: C, withContext context: Context) {
        super.register(component: component, withContext: context)

        // app.middleware.use(GraphQLMiddleWare())

        let method = context.get(valueFor: HTTPMethodContextKey.self)
        let guards = context.get(valueFor: GuardContextKey.self)
        let pathArray = context.get(valueFor: PathComponentContextKey.self)
        let responseTransformerTypes = context.get(valueFor: ResponseContextKey.self)
//        print("HANDLE->", component.handle())
//        print("PATHS", paths)
//        print("GRAPHQL->", type(of: method), method.string)

        if (method == HTTPMethod.POST) {
            // let requestHandler = context.createRequestHandler(withComponent: component)
            let pathArray = context.get(valueFor: PathComponentContextKey.self)
            var mainPathList: [String] = []
            for pa in pathArray {
                if let current_var = pa as? String {
                    mainPathList.append(current_var)
                }
            }
//            print(mainPathList)
            let path = mainPathList.joined(separator: "/")
            let guards = context.get(valueFor: GuardContextKey.self)

            answer.update_functionality(path, AnswerType((component.handle() as? String ?? "Couldn't do it")))
//            print("GUARDS->", guards)
//            print(path)
//            print("GRAPHQL CONTEXT: ", context.get(valueFor: PathComponentContextKey.self))
//            print("GROUP: ", pathArray.joined(", "))
//            answer.update_functionality(, <#T##answer: AnswerType##AnswerType#>)
//        GraphQLPathBuilder(context.get(valueFor: PathComponentContextKey.self))
//            .routesBuilder(app)
//            .on(context.get(valueFor: HTTPMethodContextKey.self), [], use: requestHandler)

//            GraphQLPathBuilder(context.get(valueFor: PathComponentContextKey.self))
//                    .routesBuilder(app)
//                    .on(.POST, []) { req -> String in
//                        print("HEADERS", req.headers)
//                        print("BODY", req.body.string)
//                        print("DESC", req.description)
//                        return "HI"
//                    }
//            print("The routes are ->", app.routes.all)
        }

//        print("2->", type(of: paths))

//        let paths = context.get(valueFor: PathComponentContextKey.self)
//        let guards = context.get(valueFor: GuardContextKey.self)
//        let responseTransformerTypes = context.get(valueFor: ResponseContextKey.self)
//        let restLinks = context.get(valueFor: RESTCustomLinksContextKey.self)
//
//        let responseType = responseTransformerTypes.isEmpty ? C.Response.self : responseTransformerTypes.last!().transformedResponseType
//        let requestHandler = context.createRequestHandler(withComponent: component)
//
//
//        let requestHandler = context.createRequestHandler(withComponent: component)
//        print("GRAPHQL CONTEXT: ", context.get(valueFor: PathComponentContextKey.self))
////        GraphQLPathBuilder(context.get(valueFor: PathComponentContextKey.self))
////            .routesBuilder(app)
////            .on(context.get(valueFor: HTTPMethodContextKey.self), [], use: requestHandler)
//
//        GraphQLPathBuilder(context.get(valueFor: PathComponentContextKey.self))
//                .routesBuilder(app)
//                .on(.POST, []) { req -> String in
//                    print("HEADERS", req.headers)
//                    print("BODY", req.body.string)
//                    print("DESC", req.description)
//                    return "HI"
//                }
//        print("The routes are ->", app.routes.all)

//        RESTPathBuilder(context.get(valueFor: PathComponentContextKey.self))
//            .routesBuilder(app)
//            .on(context.get(valueFor: HTTPMethodContextKey.self), [], use: requestHandler)

        // let component : RoutingKit.PathComponent =  "graphql/"  + (component.handle() as! String)
        //        if type(of: component) == Text.self {
        //            let query = GraphQLQueryBuilder(withQueryFunctions: []).buildQuery()
        //            app.routes.graphql(path: "graphql", use: query.self, includeGraphiQL: .always)
        //        }
        //        print(component)
        //        print(type(of: component))
        ////        print(component.response())
        //        print(context)
        //        print("Register called")
    }
}

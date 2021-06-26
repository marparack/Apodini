import Fluent
import Apodini
import ApodiniExtension

/// Creates, if possible, an array of object in the database that conform to `DatabaseModel`
/// See also `Create`.
public struct CreateAll<Model: DatabaseModel>: Handler {
    @ApodiniExtension.Environment(\.database)
    private var database: Fluent.Database
    
    @Environment(\.eventLoopGroup)
    private var eventLoopGroup: EventLoopGroup
    
    @Parameter
    private var objects: [Model]
    
    
    public init() {}
    
    
    public func handle() -> EventLoopFuture<Response<[Model]>> {
        eventLoopGroup.next()
            .flatten(
                objects.compactMap { object in
                    object.save(on: database)
                }
            )
            .map { _ in
                .final(objects, status: .created)
            }
    }
}

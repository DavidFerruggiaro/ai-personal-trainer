import Foundation
import SwiftData

public enum TrainerPersistenceContainer {
    public static var schema: Schema {
        Schema(versionedSchema: TrainerPersistenceSchemaV1.self)
    }

    public static func makeDefault() throws -> ModelContainer {
        let schema = self.schema
        let configuration = ModelConfiguration(
            "TrainerPersistence",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try make(configuration: configuration)
    }

    public static func makeInMemory() throws -> ModelContainer {
        let schema = self.schema
        let configuration = ModelConfiguration(
            "TrainerPersistenceTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try make(configuration: configuration)
    }

    public static func make(at storeURL: URL) throws -> ModelContainer {
        let schema = self.schema
        let configuration = ModelConfiguration(
            "TrainerPersistence",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try make(configuration: configuration)
    }

    private static func make(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: TrainerPersistenceMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

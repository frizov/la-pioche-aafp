import Fluent
import Vapor

final class Game: Model, @unchecked Sendable {
    static let schema = "games"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "min_players")
    var minPlayers: Int

    @Field(key: "max_players")
    var maxPlayers: Int

    @Field(key: "duration_minutes")
    var durationMinutes: Int

    @Children(for: \.$game)
    var loans: [Loan]

    init() {}

    init(id: UUID? = nil, title: String, minPlayers: Int, maxPlayers: Int, durationMinutes: Int) {
        self.id = id
        self.title = title
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.durationMinutes = durationMinutes
    }
}

extension Game {
    func apply(with updateDTO: UpdateGameDTO) {
        self.title = updateDTO.title
        self.minPlayers = updateDTO.minPlayers
        self.maxPlayers = updateDTO.maxPlayers
        self.durationMinutes = updateDTO.durationMinutes
    }
}


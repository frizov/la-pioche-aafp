import Vapor

struct GameDTO: Content {
    let id: UUID?
    let title: String
    let minPlayers: Int
    let maxPlayers: Int
    let durationMinutes: Int
    let isAvailable: Bool
    let loans: [LoanDTO]?
}

extension Game {
    func toDTO() -> GameDTO {
        GameDTO(
            id: id,
            title: title,
            minPlayers: minPlayers,
            maxPlayers: maxPlayers,
            durationMinutes: durationMinutes,
            isAvailable: isAvailable,
            loans: $loans.value?.map { $0.toDTO() }
        )
    }
}

@testable import App
import XCTVapor

final class GameTests: XCTestCase {
    func testCreateGameReturnsCreated() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                let game = try res.content.decode(GameDTO.self)
                XCTAssertEqual(game.title, "Catan")
                XCTAssertTrue(game.isAvailable)
            })
        }
    }

    func testCreateGameWithEmptyTitleIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testCreateGameWithInvertedPlayerBoundsIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan", minPlayers: 5, maxPlayers: 2, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    // update tests
    
    func testUpdateGameReturnsOK() async throws {
        try await withApp { app in
            let game = try await createGame(app, title: "Catan")
            let id = try XCTUnwrap(game.id)
            
            try await app.test(.PUT, "games/\(id)", beforeRequest: { req in
                try req.content.encode(UpdateGameDTO(
                    title: "Mafia", minPlayers: 5, maxPlayers: 11, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let game = try res.content.decode(GameDTO.self)
                XCTAssertEqual(game.title, "Mafia")
            })
        }
    }
    
    func testUpdateGameWithInvertedPlayerBoundsIsRejected() async throws {
        try await withApp { app in
            let game = try await createGame(app, title: "Catan")
            let id = try XCTUnwrap(game.id)
            
            try await app.test(.PUT, "games/\(id)", beforeRequest: { req in
                try req.content.encode(UpdateGameDTO(
                    title: "Mafia", minPlayers: 11, maxPlayers: 7, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testUpdateGameWithEmptyTitleIsRejected() async throws {
        try await withApp { app in
            let game = try await createGame(app, title: "Catan")
            let id = try XCTUnwrap(game.id)
            
            try await app.test(.PUT, "games/\(id)", beforeRequest: { req in
                try req.content.encode(UpdateGameDTO(
                    title: "", minPlayers: 3, maxPlayers: 11, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testUpdateGameWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.PUT, "games/not-a-uuid", beforeRequest: { req in
                try req.content.encode(UpdateGameDTO(
                    title: "Mafia", minPlayers: 3, maxPlayers: 11, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testUpdateUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.PUT, "games/\(UUID())", beforeRequest: { req in
                try req.content.encode(UpdateGameDTO(
                    title: "Mafia", minPlayers: 3, maxPlayers: 11, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testListGames() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan")
            _ = try await createGame(app, title: "Dixit")

            try await app.test(.GET, "games", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 2)
            })
        }
    }

    func testShowGame() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)

            try await app.test(.GET, "games/\(id)", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode(GameDTO.self).id, id)
            })
        }
    }

    func testShowUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/\(UUID())", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }

    func testShowGameWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/not-a-uuid", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testDeleteGameReturnsNoContent() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)
            
            try await app.test(.DELETE, "games/\(id)") { res async throws in
                XCTAssertEqual(res.status, .noContent)
            }
        }
    }
    
    func testDeleteGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.DELETE, "games/\(UUID())") { res async throws in
                XCTAssertEqual(res.status, .notFound)
            }
        }
    }
    
    func testDeleteGameMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.DELETE, "games/\not-a-uuid") { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testDeleteGameCannotBeDeletedIsNotAvailable() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)
            
            let member = try await createMember(app)
            try await insertLoan(app, gameID: game.id!, memberID: member.id!, borrowedAt: Date(), dueAt: try Loan.dueDate(from: Date()))
            
            
            try await app.test(.DELETE, "games/\(id)") { res async throws in
                XCTAssertEqual(res.status, .conflict)
            }
        }
    }
    
    func testDeleteGameIsCannotBeDeletedIsAvailable() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)
            
            let member = try await createMember(app)
            try await insertLoan(app, gameID: game.id!, memberID: member.id!, borrowedAt: Date(), dueAt: try Loan.dueDate(from: Date()), returnedAt: Date())
 
            try await app.test(.DELETE, "games/\(id)") { res async throws in
                XCTAssertEqual(res.status, .conflict)
            }
        }
    }
    
    

    func testPreflightRequestFromAnotherOriginIsAllowed() async throws {
        try await withApp { app in
            try await app.test(.OPTIONS, "games", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "http://localhost:8080")
                req.headers.replaceOrAdd(name: .accessControlRequestMethod, value: "POST")
                req.headers.replaceOrAdd(name: .accessControlRequestHeaders, value: "content-type")
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.headers.first(name: .accessControlAllowOrigin), "*")
                XCTAssertTrue(res.headers[.accessControlAllowMethods].joined(separator: ",").contains("POST"))
            })
        }
    }

    func testErrorResponsesCarryTheCorsHeaders() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/not-a-uuid", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "http://localhost:8080")
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
                XCTAssertEqual(res.headers.first(name: .accessControlAllowOrigin), "*")
            })
        }
    }
}

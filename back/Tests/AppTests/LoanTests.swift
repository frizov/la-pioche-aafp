@testable import App
import XCTVapor

final class LoanTests: XCTestCase {
    private func borrow(
        _ app: Application,
        gameID: UUID,
        memberID: UUID,
        afterResponse: (XCTHTTPResponse) async throws -> Void
    ) async throws {
        try await app.test(.POST, "loans", beforeRequest: { req in
            try req.content.encode(CreateLoanDTO(gameID: gameID, memberID: memberID))
        }, afterResponse: afterResponse)
    }

    func testBorrowGameReturnsCreated() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let member = try await createMember(app)

            try await borrow(
                app, gameID: try XCTUnwrap(game.id), memberID: try XCTUnwrap(member.id)
            ) { res in
                XCTAssertEqual(res.status, .created)
                let loan = try res.content.decode(LoanDTO.self)
                XCTAssertEqual(loan.gameID, game.id)
                XCTAssertEqual(loan.memberID, member.id)
                XCTAssertNil(loan.returnedAt)
            }
        }
    }

    func testDueDateIsFourteenDaysAfterBorrowDate() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let member = try await createMember(app)

            try await borrow(
                app, gameID: try XCTUnwrap(game.id), memberID: try XCTUnwrap(member.id)
            ) { res in
                let loan = try res.content.decode(LoanDTO.self)
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let days = calendar.dateComponents([.day], from: loan.borrowedAt, to: loan.dueAt).day
                XCTAssertEqual(days, 14)
            }
        }
    }

    func testBorrowedGameIsNoLongerAvailable() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let member = try await createMember(app)
            let gameID = try XCTUnwrap(game.id)

            try await borrow(app, gameID: gameID, memberID: try XCTUnwrap(member.id)) { _ in }

            try await app.test(.GET, "games/\(gameID)", afterResponse: { res async throws in
                XCTAssertFalse(try res.content.decode(GameDTO.self).isAvailable)
            })
        }
    }

    func testBorrowingAGameAlreadyOnLoanReturnsConflict() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let first = try await createMember(app, email: "first@example.com")
            let second = try await createMember(app, name: "Alex", email: "second@example.com")
            let gameID = try XCTUnwrap(game.id)

            try await borrow(app, gameID: gameID, memberID: try XCTUnwrap(first.id)) { _ in }
            try await borrow(app, gameID: gameID, memberID: try XCTUnwrap(second.id)) { res in
                XCTAssertEqual(res.status, .conflict)
            }
        }
    }

    func testBorrowUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            let member = try await createMember(app)

            try await borrow(app, gameID: UUID(), memberID: try XCTUnwrap(member.id)) { res in
                XCTAssertEqual(res.status, .notFound)
            }
        }
    }

    func testBorrowWithUnknownMemberReturnsNotFound() async throws {
        try await withApp { app in
            let game = try await createGame(app)

            try await borrow(app, gameID: try XCTUnwrap(game.id), memberID: UUID()) { res in
                XCTAssertEqual(res.status, .notFound)
            }
        }
    }
    
    func testReturnLoanReturnsOKandLoanDTOandGameIsAvailable() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let member = try await createMember(app)
            var loan: LoanDTO?
            
            try await borrow(
                app,
                gameID: try XCTUnwrap(game.id),
                memberID: try XCTUnwrap(member.id)
            ){ res in
                XCTAssertEqual(res.status, .created, res.body.string)
                loan = try res.content.decode(LoanDTO.self)
                XCTAssertNil(loan?.returnedAt)
            }
            let loanID = try XCTUnwrap(loan?.id)
            let gameID = try XCTUnwrap(loan?.gameID)
            
            try await app.test(.POST, "loans/\(loanID)/return", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok, res.body.string)
                let returnedLoan = try res.content.decode(LoanDTO.self)
                XCTAssertEqual(returnedLoan.id, loanID)
                XCTAssertEqual(returnedLoan.gameID, game.id)
                XCTAssertEqual(returnedLoan.memberID, member.id)
                XCTAssertNotNil(returnedLoan.returnedAt)
            })
            try await app.test(.GET, "games/\(gameID)") { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertTrue(try res.content.decode(GameDTO.self).isAvailable)
            }
        }
    }
    
    func testReturnLoanAlreadyReturnedReturnsConflict() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let member = try await createMember(app)
            var loan: LoanDTO?
            
            try await borrow(
                app,
                gameID: try XCTUnwrap(game.id),
                memberID: try XCTUnwrap(member.id)
            ){ res in
                XCTAssertEqual(res.status, .created, res.body.string)
                loan = try res.content.decode(LoanDTO.self)
                XCTAssertNil(loan?.returnedAt)
            }
            let loanID = try XCTUnwrap(loan?.id)
            
            try await app.test(.POST, "loans/\(loanID)/return", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
            })
            
            try await app.test(.POST, "loans/\(loanID)/return", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
        }
    }
    
    func testReturnLoanReturnsWithWrongIDReturnsNotFound() async throws {
        try await withApp { app in
            
            try await app.test(.POST, "loans/\(UUID())/return", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testReturnLoanReturnsWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            
            try await app.test(.POST, "loans/not-a-uuid/return", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
}

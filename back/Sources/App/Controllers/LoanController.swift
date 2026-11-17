import Fluent
import Vapor

struct LoanController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let loans = routes.grouped("loans")
        loans.post(use: create)
        loans.post(":loanID", "return" , use: returnLoan)
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let dto = try req.content.decode(CreateLoanDTO.self)

        guard let game = try await Game.query(on: req.db)
            .filter(\.$id == dto.gameID)
            .with(\.$loans)
            .first()
        else {
            throw Abort(.notFound, reason: "Game not found")
        }
        
        guard let member = try await Member.find(dto.memberID, on: req.db) else {
            throw Abort(.notFound, reason: "Member not found")
        }

        guard game.isAvailable else {
            throw Abort(.conflict, reason: "Game is not available")
        }
        
        let now = Date()
        let loan = Loan(
            gameID: try game.requireID(),
            memberID: try member.requireID(),
            borrowedAt: now,
            dueAt: try Loan.dueDate(from: now)
        )
        try await loan.save(on: req.db)
        return try await loan.toDTO().encodeResponse(status: .created, for: req)
    }
    
    @Sendable
    func returnLoan(req: Request) async throws -> LoanDTO {
        let loan = try await findLoan(req)
        
        guard loan.returnedAt == nil else {
            throw Abort(.conflict, reason: "Loan is already returned")
        }
        loan.returnedAt = Date()
        try await loan.save(on: req.db)
        return loan.toDTO()
    }
    
    private func findLoan(_ req: Request) async throws -> Loan {
        guard let loanID = req.parameters.get("loanID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid loan id")
        }
        guard let loan = try await Loan.query(on: req.db)
            .filter(\.$id == loanID)
            .with(\.$game)
            .with(\.$member)
            .first()
                else {
            throw Abort(.notFound, reason: "Loan not found")
        }
        return loan
    }
}

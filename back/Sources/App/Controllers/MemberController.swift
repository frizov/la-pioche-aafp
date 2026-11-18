import Fluent
import Vapor

struct MemberController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let members = routes.grouped("members")
        members.get(use: index)
        members.post(use: create)
        members.put(":memberID", use: update)
        members.delete(":memberID", use: delete)
        members.get(":memberID", use: show)
        members.get(":memberID", "loans", use: showMemberLoans)
    }

    @Sendable
    func index(req: Request) async throws -> [MemberDTO] {
        try await Member.query(on: req.db).all().map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        try CreateMemberDTO.validate(content: req)
        let dto = try req.content.decode(CreateMemberDTO.self)

        let emailTaken = try await Member.query(on: req.db)
            .filter(\.$email == dto.email)
            .count() > 0
        guard !emailTaken else {
            throw Abort(.conflict, reason: "A member with this email already exists")
        }

        let member = dto.toModel()
        try await member.save(on: req.db)
        return try await member.toDTO().encodeResponse(status: .created, for: req)
    }

    @Sendable
    func show(req: Request) async throws -> MemberDTO {
        guard let memberID = req.parameters.get("memberID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid member id")
        }
        guard let member = try await Member.find(memberID, on: req.db) else {
            throw Abort(.notFound, reason: "Member not found")
        }
        return member.toDTO()
    }
    
    @Sendable
    func showMemberLoans(req: Request) async throws -> [LoanDTO] {
        let member = try await findMember(req)

        let sortedLoans = member.$loans.value?.sorted { $0.borrowedAt > $1.borrowedAt } ?? []
        let dtos = sortedLoans.map { $0.toDTO() }
        
        return dtos
    }
    
    @Sendable
    func update(req: Request) async throws -> MemberDTO {
        let member = try await findMember(req)
        
        try UpdateMemberDTO.validate(content: req)
        let updateDto = try req.content.decode(UpdateMemberDTO.self)
        
        let emailIsAvailable = try await Member.query(on: req.db)
            .filter(\.$email == updateDto.email)
            .filter(\.$id != member.requireID())
            .first() == nil
        
        guard emailIsAvailable else {
            throw Abort(.conflict, reason: "A member with this email already exists")
        }
        
        member.apply(with: updateDto)
        try await member.save(on: req.db)
        return member.toDTO()
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let member = try await findMember(req)
        if !member.loans.isEmpty {
                throw Abort(.conflict, reason: "A member with loans cannot be deleted") // good
        }
        try await member.delete(on: req.db)
        return .noContent
    }
    
    private func findMember(_ req: Request) async throws -> Member {
        guard let memberID = req.parameters.get("memberID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid member id") // good
        }
        guard let member = try await Member.query(on: req.db)
            .filter(\.$id == memberID)
            .with(\.$loans)
            .first()
        else {
            throw Abort(.notFound, reason: "Member not found") // good
        }
        return member
    }
}

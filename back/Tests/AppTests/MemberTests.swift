@testable import App
import XCTVapor

final class MemberTests: XCTestCase {
    func testCreateMemberReturnsCreated() async throws {
        try await withApp { app in
            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(CreateMemberDTO(name: "Camille", email: "camille@example.com"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                XCTAssertEqual(try res.content.decode(MemberDTO.self).name, "Camille")
            })
        }
    }

    func testCreateMemberWithInvalidEmailIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(CreateMemberDTO(name: "Camille", email: "not-an-email"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testCreateMemberWithDuplicateEmailReturnsConflict() async throws {
        try await withApp { app in
            _ = try await createMember(app)

            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(CreateMemberDTO(name: "Autre", email: "camille@example.com"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
        }
    }

    func testShowUnknownMemberReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.GET, "members/\(UUID())", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testUpdateMemberReturnsOK() async throws {
        try await withApp { app in
            let member = try await createMember(app, name: "Amandine")
            let id = try XCTUnwrap(member.id)
            
            try await app.test(.PUT, "members/\(id)", beforeRequest: { req in
                try req.content.encode(UpdateMemberDTO(
                    name: "Marlen", email: "amandine@mail.com"
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let member = try res.content.decode(MemberDTO.self)
                XCTAssertEqual(member.name, "Marlen")
                XCTAssertEqual(member.email, "amandine@mail.com")
            })
        }
    }
    
    func testUpdateMemberWithEmptyNameReturnsBadRequest() async throws {
        try await withApp { app in
            let member = try await createMember(app, name: "Amandine")
            let id = try XCTUnwrap(member.id)
            
            try await app.test(.PUT, "members/\(id)", beforeRequest: { req in
                try req.content.encode(UpdateMemberDTO(
                    name: "", email: "amandine@mail.com"
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testUpdateMemberWithEmptyEmailReturnsBadRequest() async throws {
        try await withApp { app in
            let member = try await createMember(app, name: "Amandine")
            let id = try XCTUnwrap(member.id)
            
            try await app.test(.PUT, "members/\(id)", beforeRequest: { req in
                try req.content.encode(UpdateMemberDTO(
                    name: "Amandine", email: ""
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testUpdateMemberWithSameEmailReturnsConflict() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            let id = try XCTUnwrap(member.id)
            let _ = try await createMember(app, email: "duplicate@email.com")
            
            try await app.test(.PUT, "members/\(id)", beforeRequest: { req in
                try req.content.encode(UpdateMemberDTO(
                    name: "Amandine",  email: "duplicate@email.com"
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
        }
    }
    
    func testUpdateMemberWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.PUT, "members/\not-a-uuid", beforeRequest: { req in
                try req.content.encode(UpdateMemberDTO(
                    name: "Marlen", email: "amandine@mail.com"
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testUpdateMemberReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.PUT, "members/\(UUID())", beforeRequest: { req in
                try req.content.encode(UpdateMemberDTO(
                    name: "Marlen", email: "amandine@mail.com"
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testDeleteMemberReturnsNoContent() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            let id = try XCTUnwrap(member.id)
            
            try await app.test(.DELETE, "members/\(id)") { res async throws in
                XCTAssertEqual(res.status, .noContent)
            }
        }
    }
    
    func testDeleteMemberReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.DELETE, "members/\(UUID())") { res async throws in
                XCTAssertEqual(res.status, .notFound)
            }
        }
    }
    
    func testDeleteMemberMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.DELETE, "members/\not-a-uuid") { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
    
    func testDeleteMemberCannotBeDeletedHasLoans() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            let id = try XCTUnwrap(member.id)
            
            let game = try await createGame(app)
            try await insertLoan(app, gameID: game.id!, memberID: member.id!, borrowedAt: Date(), dueAt: try Loan.dueDate(from: Date()))
            
            
            try await app.test(.DELETE, "members/\(id)") { res async throws in
                XCTAssertEqual(res.status, .conflict)
            }
        }
    }
}

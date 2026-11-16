import Fluent
import Vapor

final class Member: Model, @unchecked Sendable {
    static let schema = "members"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "email")
    var email: String

    @Children(for: \.$member)
    var loans: [Loan]

    init() {}

    init(id: UUID? = nil, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}

extension Member {
    func apply(with updateDTO: UpdateMemberDTO) {
        self.name = updateDTO.name
        self.email = updateDTO.email
    }
}

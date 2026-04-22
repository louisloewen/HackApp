import Foundation

struct Equipo: Identifiable, Equatable {
    var id: UUID = UUID()
    var firestoreId: String = ""
    var nombre: String
}

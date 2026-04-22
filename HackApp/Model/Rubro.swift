import Foundation

struct Rubro: Codable, Identifiable {
    var id = UUID()
    var firestoreId: String = ""
    var nombre: String
    var valor: Double
}

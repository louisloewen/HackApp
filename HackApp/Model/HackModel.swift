import Foundation

struct HackModel: Identifiable {
    var id: String
    var clave: String
    var descripcion: String
    var estaActivo: Bool
    var nombre: String
    var tiempoPitch: Double
    var FechaStart: Date
    var FechaEnd: Date
    var valorRubro: Int
    var estaIniciado: Bool
}

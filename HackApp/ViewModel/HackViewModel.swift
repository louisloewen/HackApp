import Foundation

class HackViewModel: ObservableObject {
    @Published var statusMessage: String = ""

    private var viewModel = HacksViewModel()

    func updateHack(
        hackId: String, nombre: String, descripcion: String,
        clave: String, valorRubro: Int, tiempoPitch: Double,
        fechaStart: Date, fechaEnd: Date,
        completion: @escaping (Bool) -> Void
    ) {
        viewModel.updateHack(
            hackId: hackId, nombre: nombre, descripcion: descripcion,
            clave: clave, valorRubro: valorRubro, tiempoPitch: tiempoPitch,
            fechaStart: fechaStart, fechaEnd: fechaEnd,
            completion: completion
        )
    }

    func updateHackStatus(hackId: String, isActive: Bool, completion: @escaping (Bool) -> Void) {
        viewModel.updateHackStatus(hackId: hackId, isActive: isActive, completion: completion)
    }

    func updateHackStart(hackId: String, completion: @escaping (Bool) -> Void) {
        viewModel.updateHackStart(hackId: hackId, completion: completion)
    }

    func fetchTeams(hackId: String, completion: @escaping (Result<[Equipo], Error>) -> Void) {
        viewModel.getTeams(hackId: hackId, completion: completion)
    }
}

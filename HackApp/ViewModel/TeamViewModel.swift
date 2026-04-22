import SwiftUI
import Foundation

class TeamViewModel: ObservableObject {
    @Published var calificaciones: [String: [String: Double]] = [:]
    @Published var rubros: [String: Double] = [:]
    @Published var totalScore: Double = 0.0
    @Published var totalJudges: Int = 0
    @Published var isLoading: Bool = true

    private var hackId: String
    private var teamId: String
    private var viewModel: HacksViewModel

    init(hackId: String, teamId: String, viewModel: HacksViewModel) {
        self.hackId = hackId
        self.teamId = teamId
        self.viewModel = viewModel
    }

    func fetchRubros() {
        viewModel.fetchRubros(hackId: hackId) { result in
            switch result {
            case .success(let rubrosData):
                DispatchQueue.main.async { self.rubros = rubrosData }
            case .failure(let error):
                print("Error al obtener rubros: \(error)")
            }
        }
    }

    func fetchCalificaciones() {
        viewModel.getTeamCalificaciones(hackId: hackId, teamId: teamId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let calificaciones):
                    self.calificaciones = calificaciones
                    self.totalJudges = calificaciones.keys.count
                    self.accumulateScores()
                case .failure(let error):
                    print("Error al obtener calificaciones: \(error)")
                }
                self.isLoading = false
            }
        }
    }

    func accumulateScores() {
        totalScore = 0.0
        for judgeScores in calificaciones.values {
            for (criterionName, score) in judgeScores {
                let weight = rubros[criterionName] ?? 0.0
                totalScore += calculateFinalScore(calificacion: score, peso: weight)
            }
        }
    }

    func calculateFinalScore(calificacion: Double, peso: Double) -> Double {
        return (calificacion * peso) / 100
    }
}

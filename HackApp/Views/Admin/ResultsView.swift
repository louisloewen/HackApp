import SwiftUI
import Charts

struct ResultsView: View {
    var hack: HackModel
    @ObservedObject var viewModel = HacksViewModel()
    @State private var teams: [Equipo] = []
    @State private var scores: [String: Double] = [:]
    @State private var calificacionesPorCriterio: [String: [String: Double]] = [:]
    @State private var topTeams: [(team: String, score: Double)] = []
    @State private var topTeamsPorCriterio: [(team: String, score: Double)] = []
    @State private var isLoading: Bool = true
    @State private var selectedCriterio: String? = nil
    @State private var teamNotes: [String: [(judgeName: String, notes: String)]] = [:]
    @State private var showNotesForTeam: String? = nil

    var body: some View {
        VStack {
            Text("Resultados del Hackathon")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
                .foregroundColor(.primary)
                .background(Color(.systemGray5))
                .cornerRadius(12)
                .shadow(radius: 5)

            if isLoading {
                ProgressView("Cargando resultados...")
                    .padding()
            } else {
                Picker("Seleccionar tipo de resultado", selection: $selectedCriterio) {
                    Text("Score General").tag(nil as String?)
                    ForEach(calificacionesPorCriterio.keys.sorted(), id: \.self) { criterio in
                        Text(criterio).tag(criterio as String?)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedCriterio) { updateTopTeamsPorCriterio() }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack {
                        if let criterio = selectedCriterio, let calificaciones = calificacionesPorCriterio[criterio] {
                            Chart(calificaciones.keys.sorted(), id: \.self) { equipo in
                                BarMark(
                                    x: .value("Puntuación", calificaciones[equipo] ?? 0.0),
                                    y: .value("Equipo", equipo)
                                )
                                .foregroundStyle(by: .value("Equipo", equipo))
                                .annotation(position: .top) {
                                    Text(String(format: "%.2f", calificaciones[equipo]!))
                                        .font(.caption)
                                        .foregroundColor(.black)
                                        .padding(5)
                                        .background(Color.white)
                                        .cornerRadius(5)
                                        .shadow(color: Color.black.opacity(0.1), radius: 1)
                                }
                            }
                            .frame(height: 500)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 8)
                        } else {
                            Chart(topTeams, id: \.team) { team in
                                BarMark(
                                    x: .value("Puntuación", team.score),
                                    y: .value("Equipo", team.team)
                                )
                                .foregroundStyle(by: .value("Equipo", team.team))
                                .annotation(position: .top) {
                                    Text(String(format: "%.2f", team.score))
                                        .font(.caption)
                                        .foregroundColor(.black)
                                        .padding(5)
                                        .background(Color.white)
                                        .cornerRadius(5)
                                        .shadow(color: Color.black.opacity(0.1), radius: 1)
                                }
                            }
                            .frame(height: 500)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 8)
                        }
                    }
                }
                .padding()
            }

            Text("Mejores Equipos")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(getRankedTeams(), id: \.team) { rankedGroup in
                        let equipo = teams.first(where: { $0.nombre == rankedGroup.team })
                        VStack(spacing: 0) {
                            NavigationLink(destination: Group {
                                if let equipo = equipo {
                                    TeamView(hack: hack, equipo: equipo)
                                }
                            }) {
                                HStack {
                                    Text(rankedGroup.team)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(String(format: "%.2f", rankedGroup.score)) / \(String(format: "%.2f", Double(hack.valorRubro)))")
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentColor)
                                }
                                .padding()
                                .background(getBackgroundColor(for: rankedGroup.team, rank: rankedGroup.rank))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 4)
                            }

                            if let notes = teamNotes[rankedGroup.team], !notes.isEmpty {
                                Button(action: {
                                    withAnimation {
                                        showNotesForTeam = showNotesForTeam == rankedGroup.team ? nil : rankedGroup.team
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "text.bubble")
                                        Text("Feedback de jueces (\(notes.count))")
                                            .font(.caption)
                                        Spacer()
                                        Image(systemName: showNotesForTeam == rankedGroup.team ? "chevron.up" : "chevron.down")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                }

                                if showNotesForTeam == rankedGroup.team {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(notes, id: \.judgeName) { note in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(note.judgeName)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.blue)
                                                Text(note.notes)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                                    .transition(.opacity)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Resultados del Hackathon")
        .onAppear { fetchScores() }
    }

    private func fetchScores() {
        viewModel.getTeams(hackId: hack.id) { result in
            if case .success(let fetchedTeams) = result {
                DispatchQueue.main.async { teams = fetchedTeams }
            }
        }
        viewModel.calculateAllScores(hackId: hack.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                if case .success(let fetchedScores) = result {
                    scores = fetchedScores
                    topTeams = fetchedScores.map { (team: $0.key, score: $0.value) }
                        .sorted { $0.score > $1.score }
                }
            }
        }
        viewModel.calculateScoresByCriterion(hackId: hack.id) { result in
            DispatchQueue.main.async {
                if case .success(let criterionScores) = result {
                    calificacionesPorCriterio = criterionScores
                    updateTopTeamsPorCriterio()
                }
            }
        }
        viewModel.getAllNotes(hackId: hack.id) { result in
            if case .success(let notes) = result {
                DispatchQueue.main.async { teamNotes = notes }
            }
        }
    }

    private func updateTopTeamsPorCriterio() {
        guard let criterio = selectedCriterio else { return }
        let calificaciones = calificacionesPorCriterio[criterio] ?? [:]
        topTeamsPorCriterio = calificaciones.map { (team: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }
    }

    private func getRankedTeams() -> [(team: String, score: Double, rank: Int)] {
        let teamsToRank = selectedCriterio != nil ? topTeamsPorCriterio : topTeams
        return teamsToRank.enumerated().map { (index, team) in
            (team: team.team, score: team.score, rank: index + 1)
        }
    }

    private func getBackgroundColor(for team: String, rank: Int) -> Color {
        guard let score = scores[team], score > 0 else { return Color.gray.opacity(0.3) }
        switch rank {
        case 1: return Color.yellow.opacity(0.6)
        case 2: return Color.gray.opacity(0.6)
        case 3: return Color.brown.opacity(0.6)
        default: return Color.green.opacity(0.3)
        }
    }
}

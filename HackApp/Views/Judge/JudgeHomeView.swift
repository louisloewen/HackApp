import SwiftUI

struct JudgeHomeView: View {
    let hackId: String
    let hackClaveInput: String
    let hackMaxScore: Int
    let judgeId: String
    let selectedJudge: String
    let nombreHack: String
    let isActive: Bool

    @State private var teams: [Equipo] = []
    @State private var evaluationStatus: [String: Bool] = [:]
    @ObservedObject var viewModel = HacksViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                Text("Hackathon: \(nombreHack)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)

                Text("Equipos participantes")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom)

                if teams.isEmpty {
                    Text("No hay equipos disponibles para evaluar.")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .padding(.top)
                } else {
                    List(teams, id: \.firestoreId) { equipo in
                        let isEvaluated = evaluationStatus[equipo.firestoreId] == true
                        HStack {
                            Image(systemName: isEvaluated ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isEvaluated ? .green : .gray)
                                .padding(.leading)

                            Text(equipo.nombre)
                                .font(.title2)
                                .fontWeight(.medium)
                                .padding(.vertical)
                                .foregroundColor(.primary)

                            Spacer()

                            if isEvaluated {
                                Text("Calificado")
                                    .font(.footnote)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemGray6)))
                        .shadow(radius: 5)
                        .padding(.vertical, 5)
                        .background(
                            NavigationLink(destination: GradeView(
                                hackId: hackId,
                                hackMaxScore: hackMaxScore,
                                team: equipo,
                                judgeId: judgeId,
                                nombreJuez: selectedJudge,
                                isActive: isActive
                            )) { EmptyView() }.opacity(0)
                        )
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .padding()
            .navigationTitle("Equipos de \(nombreHack)")
            .onAppear { fetchData() }
        }
    }

    private func fetchData() {
        viewModel.getTeams(hackId: hackId) { result in
            if case .success(let fetchedTeams) = result {
                DispatchQueue.main.async { teams = fetchedTeams }
            }
        }
        viewModel.getEvaluationStatus(hackId: hackId, judgeId: judgeId) { result in
            if case .success(let status) = result {
                DispatchQueue.main.async { evaluationStatus = status }
            }
        }
    }
}

struct JudgeHomeView_Previews: PreviewProvider {
    static var previews: some View {
        JudgeHomeView(hackId: "example", hackClaveInput: "HACK24", hackMaxScore: 10, judgeId: "judge1", selectedJudge: "Juez1", nombreHack: "Ejemplo Hackathon", isActive: false)
    }
}

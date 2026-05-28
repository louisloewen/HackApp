import SwiftUI

struct GradeView: View {
    let hackId: String
    let hackMaxScore: Int
    let team: Equipo
    let judgeId: String
    let nombreJuez: String
    let isActive: Bool

    @State private var rubros: [Rubro] = []
    @State private var scores: [String: Double] = [:]
    @State private var existingScores: [String: Double]? = nil
    @State private var judgeNotes: String = ""
    @State private var alreadyRated = false
    @State private var showConfirmationAlert = false
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel = HacksViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !isActive {
                    Text("El hackathon ha cerrado. No se puede calificar.")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(16)
                        .shadow(radius: 10)
                        .padding(.horizontal)
                } else {
                    Text("Calificación de \(team.nombre)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.top)

                    Text("Rubros de evaluación")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 12)

                    if alreadyRated {
                        alreadyRatedSection
                    } else {
                        gradingSection
                        confirmButton
                    }

                    notesSection
                }
            }
            .padding(.top, 24)
        }
        .onAppear {
            fetchRubros()
            checkAlreadyRated()
            fetchNotes()
        }
    }

    private var alreadyRatedSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
                Text("Ya has calificado este equipo.")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .shadow(radius: 5)

            VStack(alignment: .center, spacing: 16) {
                Text("Desglose de calificaciones:")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]), startPoint: .top, endPoint: .bottom))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                if let existing = existingScores {
                    VStack(spacing: 12) {
                        ForEach(rubros.sorted(by: { $0.nombre < $1.nombre }), id: \.firestoreId) { rubro in
                            HStack {
                                Text(rubro.nombre)
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .padding(.leading)
                                Spacer()
                                Text(String(format: "%.2f", existing[rubro.firestoreId] ?? 0.0))
                                    .font(.body)
                                    .foregroundColor(.black)
                                    .padding(.trailing)
                            }
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(UIColor.systemGray5)))
                        }
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }

    private var gradingSection: some View {
        VStack(spacing: 24) {
            ForEach(rubros.sorted(by: { $0.nombre < $1.nombre }), id: \.firestoreId) { rubro in
                VStack(spacing: 16) {
                    HStack {
                        Text(rubro.nombre)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 4) {
                            TextField(
                                "",
                                text: Binding(
                                    get: {
                                        String(format: "%.2f", scores[rubro.firestoreId] ?? 1.0)
                                    },
                                    set: { newText in
                                        if let parsed = Double(newText) {
                                            scores[rubro.firestoreId] = min(max(parsed, 1), Double(hackMaxScore))
                                        }
                                    }
                                )
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title3.monospacedDigit())
                            .fontWeight(.semibold)
                            .frame(width: 70)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)

                            Text("/ \(hackMaxScore)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }

                    Slider(
                        value: Binding(
                            get: { scores[rubro.firestoreId] ?? 1.0 },
                            set: { scores[rubro.firestoreId] = min(max($0, 1), Double(hackMaxScore)) }
                        ),
                        in: 1...max(Double(hackMaxScore), 1),
                        step: 1
                    )
                    .accentColor(.blue)
                    .padding(.horizontal)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.systemGroupedBackground)))
                .shadow(radius: 5)
            }
        }
        .padding(.bottom, 24)
    }

    private var confirmButton: some View {
        Button(action: { showConfirmationAlert = true }) {
            Text("Calificar")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]), startPoint: .top, endPoint: .bottom))
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(radius: 5)
        }
        .padding(.top, 24)
        .alert(isPresented: $showConfirmationAlert) {
            Alert(
                title: Text("Confirmación"),
                message: Text("¿Estás seguro de que quieres calificar? Después de esto no podrás modificar tu calificación."),
                primaryButton: .destructive(Text("Confirmar")) { submitCalificaciones() },
                secondaryButton: .cancel()
            )
        }
    }

    private var notesSection: some View {
        VStack(spacing: 16) {
            Text("Notas del Juez")
                .font(.headline)
                .foregroundColor(.primary)
            TextEditor(text: $judgeNotes)
                .frame(height: 150)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray5)))
                .shadow(radius: 5)
                .onChange(of: judgeNotes) { saveNotes() }
        }
        .padding(.horizontal)
    }

    private func fetchRubros() {
        viewModel.getRubrics(hackId: hackId) { result in
            if case .success(let fetchedRubros) = result {
                DispatchQueue.main.async {
                    rubros = fetchedRubros
                    for rubro in fetchedRubros where scores[rubro.firestoreId] == nil {
                        scores[rubro.firestoreId] = 1.0
                    }
                }
            }
        }
    }

    private func checkAlreadyRated() {
        viewModel.getEvaluation(hackId: hackId, teamId: team.firestoreId, judgeId: judgeId) { result in
            if case .success(let evalScores) = result {
                DispatchQueue.main.async {
                    alreadyRated = evalScores != nil
                    existingScores = evalScores
                }
            }
        }
    }

    private func fetchNotes() {
        viewModel.getNotes(hackId: hackId, teamId: team.firestoreId, judgeId: judgeId) { result in
            if case .success(let notes) = result {
                DispatchQueue.main.async { judgeNotes = notes }
            }
        }
    }

    private func submitCalificaciones() {
        viewModel.saveEvaluation(
            hackId: hackId,
            teamId: team.firestoreId,
            judgeId: judgeId,
            judgeName: nombreJuez,
            scores: scores,
            notes: judgeNotes
        ) { result in
            if case .success = result { dismiss() }
        }
    }

    private func saveNotes() {
        viewModel.saveNotes(hackId: hackId, teamId: team.firestoreId, judgeId: judgeId, notes: judgeNotes) { _ in }
    }
}

#Preview {
    GradeView(
        hackId: "exampleHackId",
        hackMaxScore: 10,
        team: Equipo(firestoreId: "teamId", nombre: "Equipo 1"),
        judgeId: "judgeId",
        nombreJuez: "Juez 1",
        isActive: true
    )
}

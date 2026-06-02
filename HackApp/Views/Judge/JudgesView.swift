import SwiftUI

struct JudgesView: View {
    @State private var hackClaveInput = ""
    @State private var hackId: String = ""
    @State private var hackMaxScore: Int = 10
    @State private var availableJudges: [Juez] = []
    @State private var selectedJudge: Juez? = nil
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @State private var hackNombre: String = ""
    @State private var hackIsActive: Bool = false
    @State private var hackIsStarted: Bool = false
    @ObservedObject var viewModel = HacksViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                if hasSearched && availableJudges.isEmpty {
                    Text(errorMessage ?? "No se encontró ese hack.")
                        .foregroundColor(.red)
                        .font(.title)
                        .padding()

                    Text("Por favor vuelve a ingresar la clave del hack:")
                        .font(.title)
                        .padding()

                    hackKeyField

                    searchButton("Buscar Hack")

                } else if !availableJudges.isEmpty {
                    Text("Bienvenido a \(hackNombre), por favor selecciona tu nombre:")
                        .font(.title)
                        .padding()

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(availableJudges.sorted(by: { $0.nombre < $1.nombre }), id: \.firestoreId) { judge in
                                Button(action: { selectedJudge = judge }) {
                                    Text(judge.nombre)
                                        .font(.title2)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(selectedJudge?.firestoreId == judge.firestoreId
                                            ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxHeight: 400)

                    NavigationLink(destination: Group {
                        if let judge = selectedJudge {
                            JudgeHomeView(
                                hackId: hackId,
                                hackClaveInput: hackClaveInput,
                                hackMaxScore: hackMaxScore,
                                judgeId: judge.firestoreId,
                                selectedJudge: judge.nombre,
                                nombreHack: hackNombre,
                                isActive: hackIsActive,
                                isStarted: hackIsStarted
                            )
                        }
                    }) {
                        Text("Presiona aquí, para comenzar a calificar")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(selectedJudge == nil ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(selectedJudge == nil)
                    .padding()

                } else {
                    Text("Por favor ingresa la clave del hack:")
                        .font(.title)
                        .padding()

                    hackKeyField

                    searchButton("Buscar Jueces")
                }

            }
        }
    }

    private var hackKeyField: some View {
        TextField("Ingrese la clave del Hack", text: $hackClaveInput)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding()
            .autocorrectionDisabled(true)
            .onSubmit { fetchHackData() }
    }

    private func searchButton(_ label: String) -> some View {
        Button(action: { fetchHackData() }) {
            Text(label)
                .fontWeight(.bold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
    }

    private func fetchHackData() {
        viewModel.fetchHack(byKey: hackClaveInput) { result in
            switch result {
            case .success(let hack):
                hackId = hack.id
                hackNombre = hack.nombre
                hackIsActive = hack.estaActivo
                hackIsStarted = hack.estaIniciado
                hackMaxScore = hack.valorRubro
                fetchJudges(hackId: hack.id)
            case .failure:
                availableJudges = []
                errorMessage = "No se ha encontrado ese hack."
                hasSearched = true
            }
        }
    }

    private func fetchJudges(hackId: String) {
        viewModel.getJudges(hackId: hackId) { result in
            switch result {
            case .success(let judges):
                availableJudges = judges
                errorMessage = judges.isEmpty ? "No se han encontrado jueces para el hack." : nil
                hasSearched = true
            case .failure:
                availableJudges = []
                errorMessage = "Error al obtener jueces."
                hasSearched = true
            }
        }
    }
}

struct JudgesView_Previews: PreviewProvider {
    static var previews: some View {
        JudgesView()
    }
}


import SwiftUI

struct AddHackForm: View {
    @ObservedObject var formData: FormDataViewModel
    @ObservedObject var listaHacks: HacksViewModel
    @Binding var showingAlert: Bool
    @State private var alertMessage: String = ""
    @State private var showSameDateWarning = false
    @State private var showingAddRubroPopover = false
    @State private var showingAddEquipoPopover = false
    @State private var showingAddJuezPopover = false
    @State private var rubroNombre: String = ""
    @State private var rubroValor: String = ""
    @State private var equipoNombre: String = ""
    @State private var juezNombre: String = ""
    @State private var rubroAEditar: Rubro?
    @State private var juezAEditar: Juez?
    @State private var equipoAEditar: Equipo?
    @ObservedObject var listaRubros = RubroViewModel()
    @ObservedObject var listaEquipos = EquipoViewModel()
    @ObservedObject var listaJueces = JuezViewModel()

    @State private var showBasicInfo = true
    @State private var showDates = false
    @State private var showRubros = false
    @State private var showEquipos = false
    @State private var showJueces = false

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 16) {
                    collapsibleSection(title: "Información Básica", isExpanded: $showBasicInfo) {
                        basicInfoContent
                    }
                    collapsibleSection(title: "Fechas", isExpanded: $showDates) {
                        dateContent
                    }
                    collapsibleSection(title: "Rúbrica", isExpanded: $showRubros) {
                        rubrosContent
                    }
                    collapsibleSection(title: "Equipos", isExpanded: $showEquipos) {
                        equiposContent
                    }
                    collapsibleSection(title: "Jueces", isExpanded: $showJueces) {
                        juecesContent
                    }
                }
                .padding()
            }

            Button(action: validateAndSave) {
                Text("Guardar Hackathon")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("⚠️ Aviso sobre fechas", isPresented: $showSameDateWarning) {
            Button("Continuar de todos modos") { proceedWithSave() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("La fecha de inicio y la fecha de fin son el mismo día. ¿Deseas continuar de todos modos?")
        }
    }

    private func collapsibleSection<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(12)
            .onTapGesture { withAnimation { isExpanded.wrappedValue.toggle() } }

            if isExpanded.wrappedValue {
                content()
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
    }

    private var basicInfoContent: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nombre del Hackathon").font(.subheadline).foregroundColor(.secondary)
                TextField("Nombre del hack", text: $formData.nombre)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Clave del Hackathon").font(.subheadline).foregroundColor(.secondary)
                TextField("Clave del hack", text: $formData.clave)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Descripción del Hackathon").font(.subheadline).foregroundColor(.secondary)
                TextField("Descripción del hack", text: $formData.descripcion)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Duración del pitch (minutos)").font(.subheadline).foregroundColor(.secondary)
                TextField("Ej: 5", text: $formData.tiempoPitch)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
        }
        .padding(.horizontal)
    }

    private var dateContent: some View {
        VStack(spacing: 12) {
            DatePicker("Fecha de inicio", selection: $formData.date, displayedComponents: .date)
            DatePicker("Fecha de fin", selection: $formData.dateEnd, displayedComponents: .date)
        }
        .padding(.horizontal)
    }

    private var rubrosContent: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Valor de la calificación máxima").font(.subheadline).foregroundColor(.secondary)
                TextField("Valor máximo de los rubros (Ej: 1-100)", text: $formData.valorRubro)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            AddRubroButton(
                showingAddRubroPopover: $showingAddRubroPopover,
                listaRubros: listaRubros,
                rubroNombre: $rubroNombre,
                rubroValor: $rubroValor,
                showingAlert: $showingAlert,
                rubroAEditar: $rubroAEditar
            )
            ForEach(listaRubros.rubroList, id: \.id) { rubro in
                HStack {
                    Text(rubro.nombre)
                    Spacer()
                    Text("\(rubro.valor, specifier: "%.0f")%")
                    Menu {
                        Button(action: {
                            rubroAEditar = rubro
                            rubroNombre = rubro.nombre
                            rubroValor = "\(rubro.valor)"
                            showingAddRubroPopover.toggle()
                        }) {
                            Label("Editar", systemImage: "pencil.circle.fill")
                                .foregroundColor(.yellow)
                        }
                        Button(action: { eliminarRubro(rubro) }) {
                            Label("Eliminar", systemImage: "trash.circle.fill")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var equiposContent: some View {
        VStack(spacing: 12) {
            AddEquipoButton(
                showingAddEquipoPopover: $showingAddEquipoPopover,
                listaEquipos: listaEquipos,
                equipoNombre: $equipoNombre,
                showingAlert: $showingAlert,
                equipoAEditar: $equipoAEditar
            )
            ForEach(listaEquipos.equipoList, id: \.id) { equipo in
                HStack {
                    Text(equipo.nombre)
                    Spacer()
                    Menu {
                        Button(action: {
                            equipoAEditar = equipo
                            equipoNombre = equipo.nombre
                            showingAddEquipoPopover.toggle()
                        }) {
                            Label("Editar", systemImage: "pencil.circle.fill")
                                .foregroundColor(.yellow)
                        }
                        Button(action: { eliminarEquipo(equipo) }) {
                            Label("Eliminar", systemImage: "trash.circle.fill")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var juecesContent: some View {
        VStack(spacing: 12) {
            AddJuezButton(
                showingAddJuezPopover: $showingAddJuezPopover,
                listaJueces: listaJueces,
                juezNombre: $juezNombre,
                showingAlert: $showingAlert,
                juezAEditar: $juezAEditar
            )
            ForEach(listaJueces.juezList, id: \.id) { juez in
                HStack {
                    Text(juez.nombre)
                    Spacer()
                    Menu {
                        Button(action: {
                            juezAEditar = juez
                            juezNombre = juez.nombre
                            showingAddJuezPopover.toggle()
                        }) {
                            Label("Editar", systemImage: "pencil.circle.fill")
                                .foregroundColor(.yellow)
                        }
                        Button(action: { eliminarJuez(juez) }) {
                            Label("Eliminar", systemImage: "trash.circle.fill")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    func eliminarRubro(_ rubro: Rubro) {
        listaRubros.eliminarRubro(rubro)
    }

    func eliminarEquipo(_ equipo: Equipo) {
        listaEquipos.eliminarEquipo(equipo)
    }

    func eliminarJuez(_ juez: Juez) {
        listaJueces.eliminarJuez(juez)
    }

    private func validateAndSave() {
        if formData.nombre.isEmpty {
            alertMessage = "El nombre es obligatorio."
            showingAlert = true
            return
        }

        if formData.clave.isEmpty {
            alertMessage = "La clave es obligatoria."
            showingAlert = true
            return
        }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: formData.date)
        let endDay = calendar.startOfDay(for: formData.dateEnd)

        if startDay > endDay {
            alertMessage = "La fecha de inicio no puede ser posterior a la fecha de fin."
            showingAlert = true
            return
        }

        if startDay == endDay {
            showSameDateWarning = true
            return
        }

        if formData.tiempoPitch.isEmpty {
            alertMessage = "El tiempo de pitch es obligatorio."
            showingAlert = true
            return
        }

        if let tiempo = Double(formData.tiempoPitch), tiempo < 0 {
            alertMessage = "El valor máximo del tiempo de pitch debe ser un número mayor a 0."
            showingAlert = true
            return
        }

        if !isNumeric(formData.tiempoPitch) {
            alertMessage = "El tiempo de pitch debe contener solo números."
            showingAlert = true
            return
        }

        if formData.valorRubro.isEmpty {
            alertMessage = "El valor máximo de los rubros es obligatorio."
            showingAlert = true
            return
        }

        if let valor = Double(formData.valorRubro), valor < 0 {
            alertMessage = "El valor máximo de los rubros debe ser un número mayor a 0."
            showingAlert = true
            return
        }

        if !isNumeric(formData.valorRubro) {
            alertMessage = "El valor de los rubros debe contener solo números."
            showingAlert = true
            return
        }

        if listaRubros.rubroList.isEmpty {
            alertMessage = "Debe agregar al menos un rubro."
            showingAlert = true
            return
        }

        let totalRubroValue = listaRubros.rubroList.reduce(0) { $0 + $1.valor }
        if totalRubroValue < 100 {
            alertMessage = "La suma de los valores de los rubros debe ser al menos 100."
            showingAlert = true
            return
        }

        if listaEquipos.equipoList.isEmpty {
            alertMessage = "Debe agregar al menos un equipo."
            showingAlert = true
            return
        }

        if listaJueces.juezList.isEmpty {
            alertMessage = "Debe agregar al menos un juez."
            showingAlert = true
            return
        }

        proceedWithSave()
    }

    private func proceedWithSave() {
        listaHacks.checkIfKeyExists(formData.clave) { exists in
            if exists {
                DispatchQueue.main.async {
                    alertMessage = "No se puede guardar porque ya existe un hack con esa clave."
                    showingAlert = true
                }
                return
            }

            listaHacks.addHack(
                nombre: formData.nombre,
                clave: formData.clave,
                descripcion: formData.descripcion,
                fechaStart: formData.date,
                fechaEnd: formData.dateEnd,
                valorRubro: Int(formData.valorRubro) ?? 0,
                tiempoPitch: Double(formData.tiempoPitch) ?? 0.0,
                teams: listaEquipos.equipoList.map { $0.nombre },
                judges: listaJueces.juezList.map { $0.nombre },
                rubrics: listaRubros.rubroList
            ) { result in
                switch result {
                case .success:
                    formData.resetForm()
                    presentationMode.wrappedValue.dismiss()
                    listaHacks.fetchHacks()
                case .failure(let error):
                    alertMessage = "Error al guardar el hack: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

private func isNumeric(_ str: String) -> Bool {
    let numericCharacterSet = CharacterSet(charactersIn: "0123456789.")
    return str.rangeOfCharacter(from: numericCharacterSet.inverted) == nil
}

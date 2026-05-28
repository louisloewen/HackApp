import Foundation
import FirebaseFirestore

class HacksViewModel: ObservableObject {
    @Published var hacks: [HackModel] = []
    @Published var isLoading = false
    @Published var nombre: String = ""
    @Published var isActive: Bool = false

    private let db = Firestore.firestore()

    // MARK: - Hackathon CRUD

    func fetchHacks() {
        isLoading = true
        db.collection("hackathons").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let docs = snapshot?.documents, error == nil else { return }
                self.hacks = docs.compactMap { Self.hackModel(from: $0) }
                    .sorted { $0.FechaEnd > $1.FechaEnd }
            }
        }
    }

    func fetchHack(byKey clave: String, completion: @escaping (Result<HackModel, Error>) -> Void) {
        db.collection("hackathons").whereField("keyCode", isEqualTo: clave).getDocuments { snapshot, error in
            if let error = error { completion(.failure(error)); return }
            guard let doc = snapshot?.documents.first, let hack = Self.hackModel(from: doc) else {
                completion(.failure(NSError(domain: "Firestore", code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Hackathon no encontrado."])))
                return
            }
            completion(.success(hack))
        }
    }

    func checkIfKeyExists(_ clave: String, completion: @escaping (Bool) -> Void) {
        db.collection("hackathons").whereField("keyCode", isEqualTo: clave).getDocuments { snapshot, _ in
            completion((snapshot?.documents.count ?? 0) > 0)
        }
    }

    func addHack(
        nombre: String, clave: String, descripcion: String,
        fechaStart: Date, fechaEnd: Date,
        valorRubro: Int, tiempoPitch: Double,
        teams: [String], judges: [String], rubrics: [Rubro],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let hackRef = db.collection("hackathons").document()
        let batch = db.batch()

        batch.setData([
            "keyCode": clave,
            "name": nombre,
            "description": descripcion,
            "isActive": true,
            "isStarted": false,
            "pitchTime": tiempoPitch,
            "startDate": Timestamp(date: fechaStart),
            "endDate": Timestamp(date: fechaEnd),
            "maxScore": valorRubro
        ], forDocument: hackRef)

        for (index, team) in teams.enumerated() {
            let teamRef = hackRef.collection("teams").document()
            batch.setData(["name": team, "order": index], forDocument: teamRef)
        }

        for judge in judges {
            let judgeRef = hackRef.collection("judges").document()
            batch.setData(["name": judge], forDocument: judgeRef)
        }

        for rubric in rubrics {
            let rubricRef = hackRef.collection("rubricCriteria").document()
            batch.setData(["name": rubric.nombre, "weight": rubric.valor], forDocument: rubricRef)
        }

        batch.commit { error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(())) }
        }
    }

    func updateHack(
        hackId: String, nombre: String, descripcion: String,
        clave: String, valorRubro: Int, tiempoPitch: Double,
        fechaStart: Date, fechaEnd: Date,
        completion: @escaping (Bool) -> Void
    ) {
        db.collection("hackathons").document(hackId).updateData([
            "name": nombre,
            "description": descripcion,
            "keyCode": clave,
            "maxScore": valorRubro,
            "pitchTime": tiempoPitch,
            "startDate": Timestamp(date: fechaStart),
            "endDate": Timestamp(date: fechaEnd)
        ]) { error in completion(error == nil) }
    }

    func updateHackStatus(hackId: String, isActive: Bool, completion: @escaping (Bool) -> Void) {
        db.collection("hackathons").document(hackId).updateData(["isActive": isActive]) { error in
            completion(error == nil)
        }
    }

    func updateHackStart(hackId: String, completion: @escaping (Bool) -> Void) {
        db.collection("hackathons").document(hackId).updateData(["isStarted": true]) { error in
            completion(error == nil)
        }
    }

    func deleteHack(hackId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let hackRef = db.collection("hackathons").document(hackId)
        deleteSubcollections(of: hackRef, subcollections: ["judges", "rubricCriteria"]) {
            self.deleteTeamsWithEvaluations(hackRef: hackRef) {
                hackRef.delete { error in
                    if let error = error { completion(.failure(error)) }
                    else { completion(.success(())) }
                }
            }
        }
    }

    private func deleteSubcollections(of ref: DocumentReference, subcollections: [String], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        for sub in subcollections {
            group.enter()
            ref.collection(sub).getDocuments { snapshot, _ in
                let batch = self.db.batch()
                snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                batch.commit { _ in group.leave() }
            }
        }
        group.notify(queue: .main, execute: completion)
    }

    private func deleteTeamsWithEvaluations(hackRef: DocumentReference, completion: @escaping () -> Void) {
        hackRef.collection("teams").getDocuments { snapshot, _ in
            guard let teamDocs = snapshot?.documents, !teamDocs.isEmpty else { completion(); return }
            let group = DispatchGroup()
            for teamDoc in teamDocs {
                group.enter()
                teamDoc.reference.collection("evaluations").getDocuments { evalSnapshot, _ in
                    let batch = self.db.batch()
                    evalSnapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                    batch.deleteDocument(teamDoc.reference)
                    batch.commit { _ in group.leave() }
                }
            }
            group.notify(queue: .main, execute: completion)
        }
    }

    // MARK: - Subcollection Reads

    func getTeams(hackId: String, completion: @escaping (Result<[Equipo], Error>) -> Void) {
        db.collection("hackathons").document(hackId).collection("teams").getDocuments { snapshot, error in
            if let error = error { completion(.failure(error)); return }
            let teams = (snapshot?.documents ?? []).compactMap { doc -> Equipo? in
                guard let name = doc.data()["name"] as? String else { return nil }
                let order = doc.data()["order"] as? Int ?? 0
                return Equipo(firestoreId: doc.documentID, nombre: name, order: order)
            }
            completion(.success(teams.sorted { $0.order < $1.order }))
        }
    }

    func getJudges(hackId: String, completion: @escaping (Result<[Juez], Error>) -> Void) {
        db.collection("hackathons").document(hackId).collection("judges").getDocuments { snapshot, error in
            if let error = error { completion(.failure(error)); return }
            let judges = (snapshot?.documents ?? []).compactMap { doc -> Juez? in
                guard let name = doc.data()["name"] as? String else { return nil }
                return Juez(firestoreId: doc.documentID, nombre: name)
            }
            completion(.success(judges))
        }
    }

    func getRubrics(hackId: String, completion: @escaping (Result<[Rubro], Error>) -> Void) {
        db.collection("hackathons").document(hackId).collection("rubricCriteria").getDocuments { snapshot, error in
            if let error = error { completion(.failure(error)); return }
            let rubrics = (snapshot?.documents ?? []).compactMap { doc -> Rubro? in
                guard let name = doc.data()["name"] as? String,
                      let weight = doc.data()["weight"] as? Double else { return nil }
                return Rubro(firestoreId: doc.documentID, nombre: name, valor: weight)
            }
            completion(.success(rubrics))
        }
    }

    /// Returns [criterionName: weight] for backward compatibility with TeamViewModel display.
    func fetchRubros(hackId: String, completion: @escaping (Result<[String: Double], Error>) -> Void) {
        getRubrics(hackId: hackId) { result in
            switch result {
            case .success(let rubrics):
                completion(.success(Dictionary(uniqueKeysWithValues: rubrics.map { ($0.nombre, $0.valor) })))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Evaluations

    func saveEvaluation(
        hackId: String, teamId: String, judgeId: String, judgeName: String,
        scores: [String: Double], notes: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("hackathons").document(hackId)
            .collection("teams").document(teamId)
            .collection("evaluations").document(judgeId)
            .setData([
                "judgeName": judgeName,
                "scores": scores,
                "notes": notes,
                "submittedAt": Timestamp()
            ]) { error in
                if let error = error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
    }

    /// Returns [criterionId: score] for the judge's evaluation, or nil if not yet submitted.
    func getEvaluation(hackId: String, teamId: String, judgeId: String, completion: @escaping (Result<[String: Double]?, Error>) -> Void) {
        db.collection("hackathons").document(hackId)
            .collection("teams").document(teamId)
            .collection("evaluations").document(judgeId)
            .getDocument { snapshot, error in
                if let error = error { completion(.failure(error)); return }
                guard let data = snapshot?.data(), snapshot?.exists == true else {
                    completion(.success(nil)); return
                }
                completion(.success(data["scores"] as? [String: Double]))
            }
    }

    func saveNotes(hackId: String, teamId: String, judgeId: String, notes: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("hackathons").document(hackId)
            .collection("teams").document(teamId)
            .collection("evaluations").document(judgeId)
            .setData(["notes": notes], merge: true) { error in
                if let error = error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
    }

    func getNotes(hackId: String, teamId: String, judgeId: String, completion: @escaping (Result<String, Error>) -> Void) {
        db.collection("hackathons").document(hackId)
            .collection("teams").document(teamId)
            .collection("evaluations").document(judgeId)
            .getDocument { snapshot, error in
                if let error = error { completion(.failure(error)); return }
                let notes = snapshot?.data()?["notes"] as? String ?? ""
                completion(.success(notes))
            }
    }

    func getAllNotes(hackId: String, completion: @escaping (Result<[String: [(judgeName: String, notes: String)]], Error>) -> Void) {
        getTeams(hackId: hackId) { teamResult in
            switch teamResult {
            case .failure(let e): completion(.failure(e))
            case .success(let teams):
                self.collectAllNotes(hackId: hackId, teams: teams, completion: completion)
            }
        }
    }

    private func collectAllNotes(
        hackId: String, teams: [Equipo],
        index: Int = 0, result: [String: [(judgeName: String, notes: String)]] = [:],
        completion: @escaping (Result<[String: [(judgeName: String, notes: String)]], Error>) -> Void
    ) {
        guard index < teams.count else { completion(.success(result)); return }
        let team = teams[index]
        db.collection("hackathons").document(hackId)
            .collection("teams").document(team.firestoreId)
            .collection("evaluations").getDocuments { snapshot, error in
                var updated = result
                var teamNotes: [(judgeName: String, notes: String)] = []
                for doc in snapshot?.documents ?? [] {
                    let data = doc.data()
                    let judgeName = data["judgeName"] as? String ?? "Unknown"
                    let notes = data["notes"] as? String ?? ""
                    if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        teamNotes.append((judgeName: judgeName, notes: notes))
                    }
                }
                if !teamNotes.isEmpty {
                    updated[team.nombre] = teamNotes
                }
                self.collectAllNotes(hackId: hackId, teams: teams, index: index + 1, result: updated, completion: completion)
            }
    }

    /// Returns [teamId: hasBeenEvaluatedByJudge] for all teams in the hackathon.
    func getEvaluationStatus(hackId: String, judgeId: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        getTeams(hackId: hackId) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let teams):
                var status: [String: Bool] = [:]
                let group = DispatchGroup()
                for team in teams {
                    group.enter()
                    self.db.collection("hackathons").document(hackId)
                        .collection("teams").document(team.firestoreId)
                        .collection("evaluations").document(judgeId)
                        .getDocument { snapshot, _ in
                            status[team.firestoreId] = snapshot?.exists == true
                            group.leave()
                        }
                }
                group.notify(queue: .main) { completion(.success(status)) }
            }
        }
    }

    /// Returns [judgeName: [criterionName: score]] for all evaluations of a team.
    func getTeamCalificaciones(hackId: String, teamId: String, completion: @escaping (Result<[String: [String: Double]], Error>) -> Void) {
        getRubrics(hackId: hackId) { rubricResult in
            switch rubricResult {
            case .failure(let error): completion(.failure(error))
            case .success(let rubrics):
                let idToName = Dictionary(uniqueKeysWithValues: rubrics.map { ($0.firestoreId, $0.nombre) })
                self.db.collection("hackathons").document(hackId)
                    .collection("teams").document(teamId)
                    .collection("evaluations").getDocuments { snapshot, error in
                        if let error = error { completion(.failure(error)); return }
                        var result: [String: [String: Double]] = [:]
                        for doc in snapshot?.documents ?? [] {
                            let data = doc.data()
                            let judgeName = data["judgeName"] as? String ?? doc.documentID
                            if let scores = data["scores"] as? [String: Double] {
                                result[judgeName] = Dictionary(uniqueKeysWithValues:
                                    scores.compactMap { (id, score) -> (String, Double)? in
                                        guard let name = idToName[id] else { return nil }
                                        return (name, score)
                                    }
                                )
                            }
                        }
                        completion(.success(result))
                    }
            }
        }
    }

    /// Returns true if a team has at least one evaluation submitted.
    func teamHasAnyEvaluation(hackId: String, teamId: String, completion: @escaping (Bool) -> Void) {
        db.collection("hackathons").document(hackId)
            .collection("teams").document(teamId)
            .collection("evaluations").getDocuments { snapshot, _ in
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }

    /// Sets 0 scores for all judges on a team (no-show).
    func markNoShow(hackId: String, teamId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        getJudges(hackId: hackId) { judgeResult in
            switch judgeResult {
            case .failure(let e): completion(.failure(e))
            case .success(let judges):
                self.getRubrics(hackId: hackId) { rubricResult in
                    switch rubricResult {
                    case .failure(let e): completion(.failure(e))
                    case .success(let rubrics):
                        let zeroScores = Dictionary(uniqueKeysWithValues: rubrics.map { ($0.firestoreId, 0.0) })
                        let batch = self.db.batch()
                        for judge in judges {
                            let evalRef = self.db.collection("hackathons").document(hackId)
                                .collection("teams").document(teamId)
                                .collection("evaluations").document(judge.firestoreId)
                            batch.setData([
                                "judgeName": judge.nombre,
                                "scores": zeroScores,
                                "notes": "",
                                "submittedAt": Timestamp()
                            ], forDocument: evalRef)
                        }
                        batch.commit { error in
                            if let error = error { completion(.failure(error)) }
                            else { completion(.success(())) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Score Calculation

    /// Returns [teamName: finalScore] for all teams, calculated from subcollection evaluations.
    func calculateAllScores(hackId: String, completion: @escaping (Result<[String: Double], Error>) -> Void) {
        getRubrics(hackId: hackId) { rubricResult in
            switch rubricResult {
            case .failure(let e): completion(.failure(e))
            case .success(let rubrics):
                self.getTeams(hackId: hackId) { teamResult in
                    switch teamResult {
                    case .failure(let e): completion(.failure(e))
                    case .success(let teams):
                        self.calculateScoresForTeams(hackId: hackId, teams: teams, rubrics: rubrics, completion: completion)
                    }
                }
            }
        }
    }

    private func calculateScoresForTeams(
        hackId: String, teams: [Equipo], rubrics: [Rubro],
        index: Int = 0, scores: [String: Double] = [:],
        completion: @escaping (Result<[String: Double], Error>) -> Void
    ) {
        guard index < teams.count else { completion(.success(scores)); return }
        let team = teams[index]
        db.collection("hackathons").document(hackId)
            .collection("teams").document(team.firestoreId)
            .collection("evaluations").getDocuments { snapshot, error in
                var updatedScores = scores
                let docs = snapshot?.documents ?? []
                var criterionTotals: [String: (sum: Double, count: Int)] = [:]
                for doc in docs {
                    if let evalScores = doc.data()["scores"] as? [String: Double] {
                        for (criterionId, score) in evalScores {
                            criterionTotals[criterionId, default: (0, 0)].sum += score
                            criterionTotals[criterionId, default: (0, 0)].count += 1
                        }
                    }
                }
                var finalScore = 0.0
                for rubric in rubrics {
                    if let totals = criterionTotals[rubric.firestoreId], totals.count > 0 {
                        let avg = totals.sum / Double(totals.count)
                        finalScore += avg * (rubric.valor / 100.0)
                    }
                }
                updatedScores[team.nombre] = finalScore
                self.calculateScoresForTeams(hackId: hackId, teams: teams, rubrics: rubrics,
                                             index: index + 1, scores: updatedScores, completion: completion)
            }
    }

    /// Returns [criterionName: [teamName: avgScore]] for results breakdown by criterion.
    func calculateScoresByCriterion(hackId: String, completion: @escaping (Result<[String: [String: Double]], Error>) -> Void) {
        getRubrics(hackId: hackId) { rubricResult in
            switch rubricResult {
            case .failure(let e): completion(.failure(e))
            case .success(let rubrics):
                let idToName = Dictionary(uniqueKeysWithValues: rubrics.map { ($0.firestoreId, $0.nombre) })
                self.getTeams(hackId: hackId) { teamResult in
                    switch teamResult {
                    case .failure(let e): completion(.failure(e))
                    case .success(let teams):
                        self.collectCriterionScores(hackId: hackId, teams: teams, idToName: idToName, completion: completion)
                    }
                }
            }
        }
    }

    private func collectCriterionScores(
        hackId: String, teams: [Equipo], idToName: [String: String],
        index: Int = 0, result: [String: [String: (sum: Double, count: Int)]] = [:],
        completion: @escaping (Result<[String: [String: Double]], Error>) -> Void
    ) {
        guard index < teams.count else {
            var final: [String: [String: Double]] = [:]
            for (criterion, teamMap) in result {
                final[criterion] = teamMap.mapValues { $0.sum / Double($0.count) }
            }
            completion(.success(final))
            return
        }
        let team = teams[index]
        db.collection("hackathons").document(hackId)
            .collection("teams").document(team.firestoreId)
            .collection("evaluations").getDocuments { snapshot, error in
                var updatedResult = result
                for doc in snapshot?.documents ?? [] {
                    if let scores = doc.data()["scores"] as? [String: Double] {
                        for (criterionId, score) in scores {
                            guard let criterionName = idToName[criterionId] else { continue }
                            updatedResult[criterionName, default: [:]][team.nombre, default: (0, 0)].sum += score
                            updatedResult[criterionName, default: [:]][team.nombre, default: (0, 0)].count += 1
                        }
                    }
                }
                self.collectCriterionScores(hackId: hackId, teams: teams, idToName: idToName,
                                            index: index + 1, result: updatedResult, completion: completion)
            }
    }

    // MARK: - Helpers

    private static func hackModel(from doc: QueryDocumentSnapshot) -> HackModel? {
        let data = doc.data()
        guard let keyCode = data["keyCode"] as? String,
              let name = data["name"] as? String else { return nil }
        return HackModel(
            id: doc.documentID,
            clave: keyCode,
            descripcion: data["description"] as? String ?? "",
            estaActivo: data["isActive"] as? Bool ?? false,
            nombre: name,
            tiempoPitch: data["pitchTime"] as? Double ?? 0.0,
            FechaStart: (data["startDate"] as? Timestamp)?.dateValue() ?? Date(),
            FechaEnd: (data["endDate"] as? Timestamp)?.dateValue() ?? Date(),
            valorRubro: data["maxScore"] as? Int ?? 0,
            estaIniciado: data["isStarted"] as? Bool ?? false
        )
    }
}

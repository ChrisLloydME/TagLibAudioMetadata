import Foundation
import Testing
import TagLibAudioMetadata

/// Runtime reconciliation of the reviewed catalog and the public field
/// registry. A new field, missing decision row, duplicate ID, unknown adapter
/// or declaration/catalog drift fails here as well as in the Python policy
/// tests; the two checks are deliberately independent.
struct ContractFieldCoverageTests {
    @Test func contractEveryFieldHasCoverageDecision() throws {
        let catalog = try ContractCatalog.load()
        let decisions = catalog["field_decisions"] as? [[String: Any]] ?? []
        var byField: [String: [String: Any]] = [:]
        var duplicates: [String] = []
        for decision in decisions {
            guard let field = decision["field"] as? String else { continue }
            if byField[field] != nil { duplicates.append(field) }
            byField[field] = decision
        }
        var evidence = ContractCase(
            scenario: "S-FIELD-COVERAGE-01",
            runtimeTest: "contractEveryFieldHasCoverageDecision",
            adapter: "catalog+field registry"
        )
        let fields = MetadataFieldKey.allCases.sorted { $0.rawValue < $1.rawValue }
        for field in fields {
            let schema = MetadataFieldRegistry.schema(for: field)
            evidence.check("field.\(field.rawValue).schema", schema != nil)
            evidence.check("field.\(field.rawValue).decision", byField[field.rawValue] != nil)
            let decision = byField[field.rawValue]?["decision"] as? String ?? ""
            let coherent: Bool
            if decision == "supported" {
                let typed = schema.map {
                    !$0.acceptedPatchValueKinds.isEmpty
                        || $0.writeUnsupportedReason != nil
                        || $0.isArtworkField
                        || ["custom", "explicitContent"].contains(field.rawValue)
                } ?? false
                let cited = !(byField[field.rawValue]?["contracts"] as? [String] ?? []).isEmpty
                    || !(byField[field.rawValue]?["existing_runtime_tests"] as? [String] ?? []).isEmpty
                coherent = typed && cited
            } else {
                coherent = (byField[field.rawValue]?["reason"] as? String)?.isEmpty == false
            }
            evidence.check("field.\(field.rawValue).expressible-or-limited", coherent, decision)
        }
        evidence.check("field.count", fields.count == 100, "\(fields.count)")
        evidence.check("field.duplicate.decisions", duplicates.isEmpty, duplicates.joined(separator: ","))
        evidence.check("field.decision.set", Set(byField.keys) == Set(fields.map(\.rawValue)))
        try evidence.finish()
    }

    @Test func contractEveryFormatHasCoverageDecision() throws {
        let catalog = try ContractCatalog.load()
        let decisions = catalog["format_decisions"] as? [[String: Any]] ?? []
        var byFormat: [String: [String: Any]] = [:]
        var duplicates: [String] = []
        for decision in decisions {
            guard let format = decision["format"] as? String else { continue }
            if byFormat[format] != nil { duplicates.append(format) }
            byFormat[format] = decision
        }
        let claims = ContractClaimsPaths.formatClaims
        let data = try Data(contentsOf: claims)
        let claimsObject = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let capabilities = claimsObject["capabilities"] as? [[String: Any]] ?? []
        let writable = capabilities
            .filter { $0["isWritable"] as? Bool == true }
            .compactMap { $0["identifier"] as? String }
            .sorted()
        var evidence = ContractCase(
            scenario: "S-FORMAT-COVERAGE-01",
            runtimeTest: "contractEveryFormatHasCoverageDecision",
            adapter: "catalog+format claims"
        )
        for format in writable {
            let decision = byFormat[format]
            evidence.check("format.\(format).decision", decision != nil)
            let value = decision?["decision"] as? String ?? ""
            let contracts = decision?["contracts"] as? [String] ?? []
            let existing = decision?["existing_runtime_tests"] as? [String] ?? []
            let reason = decision?["reason"] as? String ?? ""
            let coherent = value == "supported"
                ? (!contracts.isEmpty || !existing.isEmpty)
                : (value == "unverified" && !reason.isEmpty)
            evidence.check("format.\(format).coherent", coherent, value)
        }
        evidence.check("format.count", writable.count == decisions.count, "\(writable.count)/\(decisions.count)")
        evidence.check("format.duplicate.decisions", duplicates.isEmpty, duplicates.joined(separator: ","))
        evidence.check("format.decision.set", Set(byFormat.keys) == Set(writable))
        try evidence.finish()
    }

    @Test func contractCatalogReconciliation() throws {
        var evidence = ContractCase(
            scenario: "S-CATALOG-RECONCILIATION-01",
            runtimeTest: "contractCatalogReconciliation",
            adapter: "catalog+declarations"
        )
        let catalog = try ContractCatalog.load()
        let contracts = try ContractCatalog.contracts()
        let audits = catalog["audit_scenarios"] as? [[String: Any]] ?? []
        var scenarioIDs: [String] = []
        var contractIDs: Set<String> = []
        let adapterIDs = Set(PublicSurfaceAdapterID.allCases.map(\.rawValue))
        for contract in contracts {
            let contractID = contract["contract_id"] as? String ?? ""
            evidence.check("contract.\(contractID).id", !contractID.isEmpty)
            evidence.check("contract.\(contractID).unique", !contractIDs.contains(contractID))
            contractIDs.insert(contractID)
            let outcome = contract["outcome"] as? String ?? ""
            evidence.check("contract.\(contractID).outcome",
                           ["supported", "read_only_reject", "unsupported_reject", "unverified"].contains(outcome))
            let adapters = contract["adapters"] as? [String] ?? []
            let unverified = outcome == "unverified"
            evidence.check("contract.\(contractID).adapters",
                           (unverified ? adapters.isEmpty : !adapters.isEmpty)
                               && adapters.allSatisfy { adapterIDs.contains($0) })
            let scenarios = contract["scenarios"] as? [[String: Any]] ?? []
            for scenario in scenarios {
                let id = scenario["scenario_id"] as? String ?? ""
                scenarioIDs.append(id)
                let budget = scenario["expected_assertions"] as? Int ?? 0
                evidence.check("scenario.\(id).budget", !id.isEmpty && budget > 0)
            }
        }
        for audit in audits {
            if let id = audit["scenario_id"] as? String { scenarioIDs.append(id) }
        }
        let declared = Set(ContractScenarioDeclarations.all)
        let catalogued = Set(scenarioIDs)
        evidence.check("scenario.declarations.unique", declared.count == ContractScenarioDeclarations.all.count)
        evidence.check("scenario.catalog.unique", catalogued.count == scenarioIDs.count)
        evidence.check("scenario.set.equal", declared == catalogued,
                       "declared-only=\(declared.symmetricDifference(catalogued))")
        evidence.check("audit.scenarios", audits.count == 4, "\(audits.count)")
        evidence.check("contract.count", contracts.count >= 25, "\(contracts.count)")
        try evidence.finish()
    }
}


extension ContractFieldCoverageTests {
    @Test func contractPreviouslyUnobservedSurfaces() throws {
        let ids: [PublicSurfaceAdapterID] = [.facadeApplyRawPatchGuarded, .facadeReplaceBasic,
            .facadeUpdateBasic, .facadeWriteRawMapStrings, .bridgeWriteRawPropertyMapValues]
        var evidence = ContractCase(scenario: "S-ADAPTER-GAPS-01",
            runtimeTest: "contractPreviouslyUnobservedSurfaces", adapter: "public.adapter.gaps")
        for id in ids {
            try ContractFixture.withCopy("flac") { url in
                try ContractFLACSeed.seed(comments: ["TITLE": ["Seed"], "CONTRACT_UNKNOWN": ["keep"]], to: url)
                let before = try ContractFLACOracle.read(url)
                evidence.check(id.rawValue + ".seed", before.values("TITLE") == ["Seed"] && before.values("CONTRACT_UNKNOWN") == ["keep"])
                let input: ContractAdapterInput
                switch id {
                case .facadeApplyRawPatchGuarded:
                    let snapshot = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
                    input = .rawPatchGuarded(.init(valuesToSet: ["TITLE": ["Changed"]]),
                        expectedVersion: try #require(snapshot.fileVersion), audio: try #require(snapshot.audioContentIdentity))
                case .facadeReplaceBasic:
                    var basic = try TagLibMetadataManager.readMetadataResult(from: url); basic.title = "Changed"
                    input = .basic(basic)
                case .facadeUpdateBasic: input = .updateBasic { $0.title = "Changed" }
                case .facadeWriteRawMapStrings: input = .rawStrings(["TITLE": "Changed"], mode: .merge, verify: false)
                default: input = .rawValues(["TITLE": ["Changed"], "CONTRACT_UNKNOWN": ["keep"]], mode: .replace, verify: false)
                }
                _ = try PublicSurfaceAdapters.invoke(id, url: url, input: input)
                let after = try ContractFLACOracle.read(url)
                evidence.check(id.rawValue + ".title", after.values("TITLE") == ["Changed"])
                evidence.check(id.rawValue + ".unknown", after.values("CONTRACT_UNKNOWN") == ["keep"])
                evidence.check(id.rawValue + ".audio", after.audio == before.audio)
            }
        }
        try evidence.finish()
    }
}

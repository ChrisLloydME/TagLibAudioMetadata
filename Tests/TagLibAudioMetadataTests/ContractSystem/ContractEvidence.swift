import Foundation
import Testing

/// One test-owned native or contract assertion. The check is recorded as well
/// as asserted so the release gate can compare expected and observed scenario
/// evidence instead of trusting suite banners or counts alone.
struct ContractCheck: Sendable {
    let name: String
    let passed: Bool
    let detail: String

    init(_ name: String, _ passed: Bool, _ detail: @autoclosure () -> String = "") {
        self.name = name
        self.passed = passed
        self.detail = detail()
    }
}

enum ContractEvidenceError: Error, CustomStringConvertible {
    case missingDirectory
    case writeFailed(String)

    var description: String {
        switch self {
        case .missingDirectory:
            return "TAGLIB_TEST_EVIDENCE_DIR is not set; canonical contract evidence was not requested."
        case .writeFailed(let reason):
            return "Could not write contract scenario evidence: \(reason)"
        }
    }
}

/// Writes one JSON record per executed scenario. Records are collected by
/// `scripts/summarize-test-run.py`, which compares the exact catalog scenario
/// set and the exact assertion budget for every scenario.
enum ContractEvidence {
    static var requestedDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment["TAGLIB_TEST_EVIDENCE_DIR"],
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func campaignIdentity() throws -> [String: String] {
        let env = ProcessInfo.processInfo.environment
        guard let id = env["TAGLIB_CAMPAIGN_ID"], !id.isEmpty,
              let mode = env["TAGLIB_CAMPAIGN_MODE"], ["debug", "release"].contains(mode),
              let source = env["TAGLIB_CAMPAIGN_SOURCE_HASH"], source.count == 64 else {
            throw ContractEvidenceError.writeFailed("missing campaign identity")
        }
        return ["id": id, "mode": mode, "source_hash": source]
    }

    static func recordInvocation(adapter: String, outcome: String) throws {
        guard let directory = requestedDirectory else { return }
        guard let test = Test.current else { throw ContractEvidenceError.writeFailed("no test context") }
        let runtime = String(test.name.split(separator: "(").first ?? Substring(test.name))
        let target = directory.appendingPathComponent("invocations", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let record: [String: Any] = ["schema_version": 1, "campaign": try campaignIdentity(),
            "runtime_test": runtime, "adapter": adapter, "outcome": outcome]
        try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            .write(to: target.appendingPathComponent(UUID().uuidString + ".json"), options: .atomic)
    }

    static func validateAssertions(scenario: String, runtime: String, adapter: String, checks: [ContractCheck]) throws {
        let url = ContractClaimsPaths.root.appendingPathComponent("scripts/package-test-system/scenario-assertions.json")
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: Any]]
        guard let expected = raw?[scenario], expected["runtime_test"] as? String == runtime,
              expected["adapter_label"] as? String == adapter,
              let names = expected["checks"] as? [String], names.sorted() == checks.map(\.name).sorted() else {
            throw ContractEvidenceError.writeFailed("assertion identity mismatch for " + scenario)
        }
    }

    static func record(
        scenario: String,
        runtimeTest: String,
        adapter: String,
        outcome: String,
        checks: [ContractCheck]
    ) throws {
        guard let directory = requestedDirectory else { return }
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw ContractEvidenceError.writeFailed("cannot create \(directory.path): \(error)")
        }
        let identity = try campaignIdentity()
        let record: [String: Any] = [
            "campaign": identity,
            "schema_version": 1,
            "scenario_id": scenario,
            "runtime_test": runtimeTest,
            "adapter": adapter,
            "outcome": outcome,
            "checks": checks.map { ["name": $0.name, "passed": $0.passed, "detail": $0.detail] },
            "check_count": checks.count,
            "passed": checks.allSatisfy(\.passed),
            "pid": ProcessInfo.processInfo.processIdentifier,
            "recorded_at": ISO8601DateFormatter().string(from: Date()),
        ]
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        } catch {
            throw ContractEvidenceError.writeFailed("cannot encode \(scenario): \(error)")
        }
        let safe = scenario.replacingOccurrences(of: "/", with: "_")
        let filename = "\(safe).\(ProcessInfo.processInfo.processIdentifier).\(UUID().uuidString).json"
        let target = directory.appendingPathComponent(filename)
        do {
            try data.write(to: target, options: .atomic)
        } catch {
            throw ContractEvidenceError.writeFailed("cannot write \(target.path): \(error)")
        }
    }
}

/// Scenario-local check collector. Every call appends a check and performs the
/// corresponding Swift Testing expectation, so a removed assertion also removes
/// recorded evidence and the canonical gate rejects the shortened budget.
struct ContractCase {
    let scenario: String
    let runtimeTest: String
    let adapter: String
    let outcome: String
    private(set) var checks: [ContractCheck] = []

    init(scenario: String, runtimeTest: String, adapter: String, outcome: String = "supported") {
        self.scenario = scenario
        self.runtimeTest = runtimeTest
        self.adapter = adapter
        self.outcome = outcome
    }

    mutating func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
        let message = detail()
        checks.append(ContractCheck(name, condition, message))
        #expect(condition, "\(scenario) [\(adapter)] \(name)\(message.isEmpty ? "" : ": \(message)")")
    }

    func finish() throws {
        try ContractEvidence.validateAssertions(scenario: scenario, runtime: runtimeTest, adapter: adapter, checks: checks)
        try ContractEvidence.record(
            scenario: scenario,
            runtimeTest: runtimeTest,
            adapter: adapter,
            outcome: outcome,
            checks: checks
        )
    }
}

/// Independent fixture verification is mandatory. A failed seed is a test
/// failure, never a skip or an early `continue` past the matrix.
struct ContractSeedFailure: Error, CustomStringConvertible {
    let fixture: String
    let reason: String
    var description: String { "Seed verification failed for \(fixture): \(reason)" }
}

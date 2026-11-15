import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import package_test_system as system  # noqa: E402


def load(name):
    return json.loads((ROOT / 'scripts/package-test-system' / name).read_text())


class SurfaceInventoryPolicy(unittest.TestCase):
    def setUp(self):
        self.inventory = load('public-surface-inventory.json')
        self.catalog = load('contract-catalog.json')
        self.fixtures = load('fixture-catalog.json')
        self.adapters = load('execution-adapters.json')
        self.fields = load('field-schema-claims.json')
        self.formats = load('format-capability-claims.json')
        self.adapter_ids = system.extract_adapter_declarations(ROOT)
        self.swift = system.extract_swift_surfaces(ROOT)
        self.bridge = system.extract_bridge_surfaces(ROOT)

    def test_reviewed_inventory_catalog_and_adapters_reconcile(self):
        self.assertEqual(system.validate_all(ROOT), {
            'surface_inventory': [], 'contract_catalog': [], 'fixtures': [], 'adapters': []
        })

    def test_new_unclassified_swift_api_fails(self):
        extracted = dict(self.swift)
        extracted['swift:TagLibMetadataManager:func:func newUnclassifiedAPI() -> Bool'] = {
            'path': 'Probe.swift', 'line': 1
        }
        errors = system.validate_surface_inventory(
            self.inventory, self.catalog, self.adapter_ids, extracted, self.bridge
        )
        self.assertTrue(any('unclassified public Swift declarations' in error for error in errors))

    def test_new_unclassified_bridge_method_fails(self):
        extracted = dict(self.bridge)
        extracted['bridge:TagLibMetadataExtractor:class_method:+ (BOOL)newRoute:(NSURL *)fileURL;'] = {
            'path': 'TagLibMetadataExtractor.h', 'line': 1
        }
        errors = system.validate_surface_inventory(
            self.inventory, self.catalog, self.adapter_ids, self.swift, extracted
        )
        self.assertTrue(any('unclassified exported bridge declarations' in error for error in errors))

    def test_duplicate_surface_id_fails(self):
        inventory = copy.deepcopy(self.inventory)
        inventory['surfaces'].append(copy.deepcopy(inventory['surfaces'][0]))
        errors = system.validate_surface_inventory(
            inventory, self.catalog, self.adapter_ids, self.swift, self.bridge
        )
        self.assertTrue(any('duplicate surface id' in error for error in errors))

    def test_internal_in_place_selectors_are_not_public_coverage(self):
        self.assertFalse(any('InPlace' in key for key in self.bridge))
        internal = (ROOT / 'Sources/CTagLibBridgeInternalAPI/include/TagLibMetadataExtractor+Internal.h').read_text()
        self.assertIn('writeMetadataInPlace', internal)

    def test_unknown_adapter_reference_fails(self):
        inventory = copy.deepcopy(self.inventory)
        inventory['surfaces'][0]['adapters'] = ['not.a.real.adapter']
        errors = system.validate_surface_inventory(
            inventory, self.catalog, self.adapter_ids, self.swift, self.bridge
        )
        self.assertTrue(any('unknown adapter' in error for error in errors))

    def test_changed_capability_requires_a_new_format_decision(self):
        formats = copy.deepcopy(self.formats)
        formats['capabilities'].append({
            'identifier': 'newcodec', 'isWritable': True, 'extensions': ['newc'],
        })
        errors = system.validate_catalog(
            self.catalog, self.inventory, self.fixtures, self.fields, formats,
            self.adapter_ids, json.loads((ROOT / 'scripts/required-test-inventory.json').read_text()),
            system.extract_scenario_declarations(ROOT),
        )
        self.assertTrue(any('format decision set mismatch' in error for error in errors))

    def test_new_advertised_field_requires_a_new_decision(self):
        fields = copy.deepcopy(self.fields)
        fields['fields'].append({
            'key': 'newField', 'category': 'basic', 'acceptedPatchValueKinds': ['text'],
            'isMultiValue': False, 'isPeopleField': False, 'isRoleQualified': False,
            'isArtworkField': False, 'targets': [],
        })
        errors = system.validate_catalog(
            self.catalog, self.inventory, self.fixtures, fields, self.formats,
            self.adapter_ids, json.loads((ROOT / 'scripts/required-test-inventory.json').read_text()),
            system.extract_scenario_declarations(ROOT),
        )
        self.assertTrue(any('field decision set mismatch' in error for error in errors))


class ContractCatalogPolicy(unittest.TestCase):
    def setUp(self):
        self.inventory = load('public-surface-inventory.json')
        self.catalog = load('contract-catalog.json')
        self.fixtures = load('fixture-catalog.json')
        self.fields = load('field-schema-claims.json')
        self.formats = load('format-capability-claims.json')
        self.adapter_ids = system.extract_adapter_declarations(ROOT)
        self.required = json.loads((ROOT / 'scripts/required-test-inventory.json').read_text())
        self.declarations = system.extract_scenario_declarations(ROOT)

    def validate(self, catalog=None):
        return system.validate_catalog(
            catalog or self.catalog, self.inventory, self.fixtures, self.fields,
            self.formats, self.adapter_ids, self.required, self.declarations,
        )

    def test_catalog_is_consistent(self):
        self.assertEqual(self.validate(), [])

    def test_omitting_a_field_decision_fails(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['field_decisions'] = catalog['field_decisions'][1:]
        errors = self.validate(catalog)
        self.assertTrue(any('field decision set mismatch' in error for error in errors))

    def test_duplicate_scenario_id_fails(self):
        catalog = copy.deepcopy(self.catalog)
        first = catalog['contracts'][0]['scenarios'][0].copy()
        catalog['contracts'][1]['scenarios'].append(first)
        errors = self.validate(catalog)
        self.assertTrue(any('duplicate scenario_id' in error for error in errors))

    def test_unsupported_row_without_rejection_fails(self):
        catalog = copy.deepcopy(self.catalog)
        for contract in catalog['contracts']:
            if contract['outcome'] == 'unsupported_reject':
                contract.pop('rejection', None)
                break
        else:
            self.fail('catalog has no rejection contract')
        errors = self.validate(catalog)
        self.assertTrue(any('has no rejection decision' in error for error in errors))

    def test_contract_without_adapter_fails(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['contracts'][0]['adapters'] = []
        errors = self.validate(catalog)
        self.assertTrue(any('has no execution adapters' in error for error in errors))

    def test_scenario_declaration_drift_fails(self):
        errors = system.validate_catalog(
            self.catalog, self.inventory, self.fixtures, self.fields, self.formats,
            self.adapter_ids, self.required, self.declarations + ['S-NEW-DECLARATION-01'],
        )
        self.assertTrue(any('scenario declarations absent from the catalog' in error for error in errors))

    def test_uncovered_mode_value_fails(self):
        catalog = copy.deepcopy(self.catalog)
        for contract in catalog['contracts']:
            modes = contract.get('modes', {})
            if 'verification' in modes:
                modes['verification'] = ['enabled']
        errors = self.validate(catalog)
        self.assertTrue(any("mode 'verification' value 'disabled'" in error for error in errors))

    def test_audit_scenario_budget_cannot_be_zero(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['audit_scenarios'][0]['expected_assertions'] = 0
        errors = self.validate(catalog)
        self.assertTrue(any('positive assertion budget' in error for error in errors))

    def test_every_runtime_test_is_in_the_required_manifest(self):
        runtime_tests = {c['runtime_test'] for c in self.catalog['contracts'] if c.get('runtime_test')}
        runtime_tests |= {a['runtime_test'] for a in self.catalog['audit_scenarios']}
        self.assertFalse(runtime_tests - set(self.required))

    def test_format_decisions_cover_all_advertised_writable_families(self):
        advertised = {c['identifier'] for c in self.formats['capabilities'] if c['isWritable']}
        decided = {d['format'] for d in self.catalog['format_decisions']}
        self.assertEqual(advertised, decided)

    def test_field_decisions_cover_all_advertised_fields(self):
        advertised = {f['key'] for f in self.fields['fields']}
        decided = {d['field'] for d in self.catalog['field_decisions']}
        self.assertEqual(advertised, decided)


class CalibrationPolicy(unittest.TestCase):
    def test_mutant_anchors_are_unique_in_reviewed_sources(self):
        mutants = json.loads((ROOT / 'scripts/calibration-mutants.json').read_text())['mutants']
        self.assertGreaterEqual(len(mutants), 10)
        ids = [m['id'] for m in mutants]
        self.assertEqual(len(ids), len(set(ids)))
        for mutant in mutants:
            for patch in mutant['patches']:
                path = ROOT / patch.get('source', patch['file'])
                self.assertTrue(path.is_file(), f"{mutant['id']} target {path}")
                self.assertEqual(path.read_text().count(patch['find']), 1,
                                 f"{mutant['id']} anchor is not unique in {path}")

    def test_contract_lane_runs_policy_calibration_and_gate(self):
        script = (ROOT / 'scripts/validate-contracts.sh').read_text()
        self.assertIn('python3 -m unittest discover -s scripts/tests', script)
        self.assertIn('python3 scripts/calibrate-test-system.py', script)
        self.assertIn('scripts/validate-tests.sh', script)

    def test_calibration_workspace_is_ignored(self):
        ignore = (ROOT / '.gitignore').read_text()
        self.assertIn('.build/', ignore)
        self.assertFalse((ROOT / '.git').joinpath('calibration').exists())

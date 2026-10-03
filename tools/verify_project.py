#!/usr/bin/env python3
"""Verify the Stage 01 Xcode project without Xcode.

This host cannot build or test the app (no macOS, no Xcode), so this script is
the substitute for the checks that do not need a compiler:

  1. parse ``project.pbxproj`` and check referential integrity;
  2. resolve every file reference against the real source tree;
  3. confirm every Swift file on disk is in exactly one target's Sources phase
     and that no file is listed twice;
  4. confirm required build settings, product types and test-target wiring;
  5. parse the workspace and scheme XML and match it against the project;
  6. validate the asset catalog JSON;
  7. lint Swift sources: encoding, line endings, tabs, balanced delimiters
     (string- and interpolation-aware);
  8. cross-check that accessibility identifiers queried by the UI tests exist
     in the app sources.

It does not replace ``xcodebuild build`` or ``xcodebuild test``.

Usage
-----
    python tools/verify_project.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from xml.etree import ElementTree

REPO_ROOT = Path(__file__).resolve().parent.parent
PROJECT_DIR = REPO_ROOT / "MomentsStudio"

APP_TARGET = "MomentsStudio"
UNIT_TEST_TARGET = "MomentsStudioTests"
UI_TEST_TARGET = "MomentsStudioUITests"

PBXPROJ_FILE = PROJECT_DIR / f"{APP_TARGET}.xcodeproj" / "project.pbxproj"
WORKSPACE_FILE = PROJECT_DIR / f"{APP_TARGET}.xcodeproj" / "project.xcworkspace" / "contents.xcworkspacedata"
SCHEME_FILE = PROJECT_DIR / f"{APP_TARGET}.xcodeproj" / "xcshareddata" / "xcschemes" / f"{APP_TARGET}.xcscheme"

SOURCE_DIRS = {
    APP_TARGET: PROJECT_DIR / APP_TARGET,
    UNIT_TEST_TARGET: PROJECT_DIR / UNIT_TEST_TARGET,
    UI_TEST_TARGET: PROJECT_DIR / UI_TEST_TARGET,
}

DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"
BUNDLE_IDENTIFIERS = {
    APP_TARGET: "com.example.MomentsStudio",
    UNIT_TEST_TARGET: "com.example.MomentsStudioTests",
    UI_TEST_TARGET: "com.example.MomentsStudioUITests",
}
PRODUCT_TYPES = {
    APP_TARGET: "com.apple.product-type.application",
    UNIT_TEST_TARGET: "com.apple.product-type.bundle.unit-test",
    UI_TEST_TARGET: "com.apple.product-type.bundle.ui-testing",
}
KNOWN_ISA = {
    "PBXBuildFile",
    "PBXContainerItemProxy",
    "PBXFileReference",
    "PBXFrameworksBuildPhase",
    "PBXGroup",
    "PBXNativeTarget",
    "PBXProject",
    "PBXResourcesBuildPhase",
    "PBXSourcesBuildPhase",
    "PBXTargetDependency",
    "XCBuildConfiguration",
    "XCConfigurationList",
}
UID_PATTERN = re.compile(r"^[0-9A-F]{24}$")

# Control labels owned by the system rather than by this app. UI tests may need
# to press them (for example the Photos picker's Cancel button), so they are
# exempt from the app-identifier check by name here instead of being hidden
# from the check inside the test.
SYSTEM_CONTROL_LABELS = {
    "Cancel",
    "Done",
    "Delete",
    "Save",
    "Photo Library",
    "Continue",
    # The system photo picker's confirm control, pressed by the Stage 02
    # import→preview regression after selecting a seeded photo.
    "Add",
    # The system photo picker's own navigation bar title.
    "Photos",
}


class Failure(Exception):
    pass


# --------------------------------------------------------------------- plist


def strip_comments(text: str) -> str:
    out: list[str] = []
    i, n = 0, len(text)
    while i < n:
        char = text[i]
        if char == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            out.append(text[i : j + 1])
            i = j + 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end == -1 else end + 2
        elif text.startswith("//", i):
            end = text.find("\n", i)
            i = n if end == -1 else end
        else:
            out.append(char)
            i += 1
    return "".join(out)


class PlistParser:
    """Minimal OpenStep (NeXTSTEP) plist reader for pbxproj files."""

    def __init__(self, text: str) -> None:
        self.text = strip_comments(text)
        self.position = 0

    def parse(self):
        value = self.parse_value()
        self.skip_space()
        if self.position != len(self.text):
            raise Failure(f"trailing data at offset {self.position}")
        return value

    def skip_space(self) -> None:
        while self.position < len(self.text) and self.text[self.position].isspace():
            self.position += 1

    def fail(self, message: str) -> None:
        line = self.text.count("\n", 0, self.position) + 1
        raise Failure(f"{message} (line {line})")

    def parse_value(self):
        self.skip_space()
        if self.position >= len(self.text):
            self.fail("unexpected end of file")
        char = self.text[self.position]
        if char == "{":
            return self.parse_dict()
        if char == "(":
            return self.parse_array()
        if char == '"':
            return self.parse_quoted()
        return self.parse_bare()

    def parse_dict(self) -> dict:
        self.position += 1
        result: dict = {}
        while True:
            self.skip_space()
            if self.position >= len(self.text):
                self.fail("unterminated dictionary")
            if self.text[self.position] == "}":
                self.position += 1
                return result
            key = self.parse_value()
            if not isinstance(key, str):
                self.fail("dictionary key must be a string")
            self.skip_space()
            if self.position >= len(self.text) or self.text[self.position] != "=":
                self.fail(f"expected '=' after key {key!r}")
            self.position += 1
            result[key] = self.parse_value()
            self.skip_space()
            if self.position >= len(self.text) or self.text[self.position] != ";":
                self.fail(f"expected ';' after value for {key!r}")
            self.position += 1

    def parse_array(self) -> list:
        self.position += 1
        items: list = []
        while True:
            self.skip_space()
            if self.position >= len(self.text):
                self.fail("unterminated array")
            if self.text[self.position] == ")":
                self.position += 1
                return items
            items.append(self.parse_value())
            self.skip_space()
            if self.position < len(self.text) and self.text[self.position] == ",":
                self.position += 1

    def parse_quoted(self) -> str:
        self.position += 1
        chars: list[str] = []
        while True:
            if self.position >= len(self.text):
                self.fail("unterminated string")
            char = self.text[self.position]
            if char == "\\":
                if self.position + 1 >= len(self.text):
                    self.fail("unterminated escape")
                escaped = self.text[self.position + 1]
                chars.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(escaped, escaped))
                self.position += 2
                continue
            if char == '"':
                self.position += 1
                return "".join(chars)
            chars.append(char)
            self.position += 1

    def parse_bare(self) -> str:
        start = self.position
        while self.position < len(self.text) and self.text[self.position] not in " \t\r\n;,=(){}":
            self.position += 1
        if start == self.position:
            self.fail("empty token")
        return self.text[start : self.position]


# ------------------------------------------------------------------- helpers


def walk_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from walk_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from walk_strings(item)


def iter_objects(objects: dict):
    for identifier, obj in objects.items():
        if isinstance(obj, dict):
            yield identifier, obj


def target_by_name(project: dict, objects: dict, name: str) -> tuple[str, dict]:
    for identifier in project["targets"]:
        obj = objects.get(identifier)
        if isinstance(obj, dict) and obj.get("name") == name:
            return identifier, obj
    raise Failure(f"target {name!r} not found in project")


def build_settings(objects: dict, configuration_list_id: str, name: str) -> dict:
    configuration_list = objects.get(configuration_list_id)
    if not isinstance(configuration_list, dict):
        raise Failure(f"missing configuration list {configuration_list_id}")
    for configuration_id in configuration_list["buildConfigurations"]:
        configuration = objects.get(configuration_id)
        if isinstance(configuration, dict) and configuration.get("name") == name:
            return configuration["buildSettings"]
    raise Failure(f"missing {name} configuration in {configuration_list_id}")


def phase_files(objects: dict, phase_id: str) -> list[tuple[str, str]]:
    phase = objects.get(phase_id)
    if not isinstance(phase, dict):
        raise Failure(f"missing build phase {phase_id}")
    result = []
    for build_file_id in phase.get("files", []):
        build_file = objects.get(build_file_id)
        if not isinstance(build_file, dict):
            raise Failure(f"missing build file {build_file_id}")
        file_reference = objects.get(build_file["fileRef"])
        if not isinstance(file_reference, dict):
            raise Failure(f"build file {build_file_id} references unknown file {build_file['fileRef']}")
        result.append((build_file_id, build_file["fileRef"]))
    return result


# -------------------------------------------------------------------- parser


def parse_pbxproj() -> tuple[dict, dict]:
    if not PBXPROJ_FILE.is_file():
        raise Failure(f"missing {PBXPROJ_FILE.relative_to(REPO_ROOT)}")
    text = PBXPROJ_FILE.read_text(encoding="utf-8")
    if not text.startswith("// !$*UTF8*$!"):
        raise Failure("pbxproj is missing the UTF-8 header comment")
    if "\r" in text:
        raise Failure("pbxproj contains CR characters; use LF line endings")
    root = PlistParser(text).parse()
    objects = root.get("objects")
    if not isinstance(objects, dict):
        raise Failure("pbxproj has no objects dictionary")
    project = objects.get(root.get("rootObject"))
    if not isinstance(project, dict) or project.get("isa") != "PBXProject":
        raise Failure("rootObject does not resolve to a PBXProject")
    return objects, project


def check_referential_integrity(objects: dict) -> list[str]:
    notes = []
    for identifier, obj in iter_objects(objects):
        if not UID_PATTERN.match(identifier):
            raise Failure(f"object id {identifier!r} is not 24 uppercase hex characters")
        if obj.get("isa") not in KNOWN_ISA:
            raise Failure(f"object {identifier} has unknown isa {obj.get('isa')!r}")
        for value in walk_strings(obj):
            if UID_PATTERN.match(value) and value not in objects:
                raise Failure(f"object {identifier} references missing object {value}")
    notes.append(f"{len(objects)} objects, all references resolved")
    return notes


def resolve_grouped_path(group_chain: list[str], file_path: str) -> str:
    return "/".join(group_chain + [file_path])


def collect_group_paths(objects: dict, project: dict):
    """Map every file reference id to its path relative to the project directory."""
    main_group = project["mainGroup"]
    paths: dict[str, str] = {}
    group_paths: dict[str, str] = {}

    def visit(group_id: str, prefix: list[str]) -> None:
        group = objects.get(group_id)
        if not isinstance(group, dict) or group.get("isa") != "PBXGroup":
            raise Failure(f"{group_id} is not a PBXGroup")
        chain = prefix + ([group["path"]] if group.get("path") else [])
        group_paths[group_id] = "/".join(chain)
        for child_id in group.get("children", []):
            child = objects.get(child_id)
            if not isinstance(child, dict):
                raise Failure(f"group {group_id} has missing child {child_id}")
            if child.get("isa") == "PBXGroup":
                visit(child_id, chain)
            elif child.get("isa") == "PBXFileReference":
                paths[child_id] = "/".join(chain + ([child["path"]] if child.get("path") else []))
            else:
                raise Failure(f"group {group_id} contains unsupported child isa {child.get('isa')!r}")

    visit(main_group, [])
    return paths, group_paths


def check_sources_on_disk(objects: dict, project: dict) -> list[str]:
    notes = []
    paths, _ = collect_group_paths(objects, project)

    resolved: dict[str, Path] = {}
    for identifier, obj in iter_objects(objects):
        if obj.get("isa") != "PBXFileReference":
            continue
        if obj.get("sourceTree") == "BUILT_PRODUCTS_DIR":
            continue
        relative = paths.get(identifier)
        if relative is None:
            raise Failure(f"file reference {identifier} ({obj.get('path')}) is not reachable from the root group")
        absolute = PROJECT_DIR / relative
        if not absolute.exists():
            raise Failure(f"file reference {identifier} points at a missing path: {absolute}")
        resolved[identifier] = absolute

    notes.append(f"{len(resolved)} file references exist on disk")
    return notes


def check_target_wiring(objects: dict, project: dict) -> tuple[list[str], dict]:
    notes = []
    info: dict = {}

    if len(project["targets"]) != 3:
        raise Failure(f"expected 3 targets, found {len(project['targets'])}")

    for target_name, expected_type in PRODUCT_TYPES.items():
        identifier, target = target_by_name(project, objects, target_name)
        if target.get("productType") != expected_type:
            raise Failure(f"{target_name} has productType {target.get('productType')!r}, expected {expected_type!r}")
        phases = target.get("buildPhases", [])
        phase_kinds = {objects[phase]["isa"] for phase in phases}
        for required in ("PBXSourcesBuildPhase", "PBXFrameworksBuildPhase", "PBXResourcesBuildPhase"):
            if required not in phase_kinds:
                raise Failure(f"{target_name} is missing a {required}")
        info[target_name] = {"id": identifier, "target": target}

    # Sources coverage: every Swift file on disk in exactly one target.
    seen: dict[Path, str] = {}
    for target_name, root in SOURCE_DIRS.items():
        identifier = info[target_name]["id"]
        target = info[target_name]["target"]
        source_phase = next(
            phase for phase in target["buildPhases"] if objects[phase]["isa"] == "PBXSourcesBuildPhase"
        )
        listed = phase_files(objects, source_phase)
        paths, _ = collect_group_paths(objects, project)
        listed_paths = set()
        for _, file_reference in listed:
            file_path = PROJECT_DIR / paths[file_reference]
            if file_path in seen:
                raise Failure(f"{file_path.relative_to(REPO_ROOT)} is in both {seen[file_path]} and {target_name}")
            seen[file_path] = target_name
            listed_paths.add(file_path)

        on_disk = {path for path in root.rglob("*.swift") if path.is_file()}
        missing = on_disk - listed_paths
        extra = listed_paths - on_disk
        if missing:
            raise Failure(
                f"{target_name} Sources phase is missing: "
                + ", ".join(sorted(str(path.relative_to(REPO_ROOT)) for path in missing))
            )
        if extra:
            raise Failure(
                f"{target_name} Sources phase lists files that no longer exist: "
                + ", ".join(sorted(str(path.relative_to(REPO_ROOT)) for path in extra))
            )
        info[target_name]["source_count"] = len(listed_paths)

    # Asset catalog must reach the app's Resources phase.
    app_identifier = info[APP_TARGET]["id"]
    app_target = info[APP_TARGET]["target"]
    resources_phase = next(
        phase for phase in app_target["buildPhases"] if objects[phase]["isa"] == "PBXResourcesBuildPhase"
    )
    resource_paths = {
        PROJECT_DIR / collect_group_paths(objects, project)[0][file_reference]
        for _, file_reference in phase_files(objects, resources_phase)
    }
    catalog = (PROJECT_DIR / APP_TARGET / "Resources" / "Assets.xcassets").resolve()
    if catalog not in {path.resolve() for path in resource_paths}:
        raise Failure("Assets.xcassets is not in the app Resources build phase")

    notes.append(
        "Sources phases cover every Swift file exactly once: "
        + ", ".join(f"{name}={info[name]['source_count']}" for name in PRODUCT_TYPES)
    )
    return notes, info


def check_build_settings(objects: dict, project: dict, info: dict) -> list[str]:
    notes = []

    project_settings = build_settings(objects, project["buildConfigurationList"], "Debug")
    if project_settings.get("SDKROOT") != "iphoneos":
        raise Failure("project SDKROOT must be iphoneos")
    if project_settings.get("IPHONEOS_DEPLOYMENT_TARGET") != DEPLOYMENT_TARGET:
        raise Failure(f"project deployment target must be {DEPLOYMENT_TARGET}")
    if project_settings.get("SWIFT_VERSION") != SWIFT_VERSION:
        raise Failure(f"project SWIFT_VERSION must be {SWIFT_VERSION}")

    for configuration in ("Debug", "Release"):
        app_settings = build_settings(objects, info[APP_TARGET]["target"]["buildConfigurationList"], configuration)
        expected = {
            "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_IDENTIFIERS[APP_TARGET],
            "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
            "SWIFT_VERSION": SWIFT_VERSION,
            "GENERATE_INFOPLIST_FILE": "YES",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
            "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        }
        for key, value in expected.items():
            if app_settings.get(key) != value:
                raise Failure(f"app {configuration} setting {key} is {app_settings.get(key)!r}, expected {value!r}")
        if "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone" not in app_settings:
            raise Failure("app target does not restrict iPhone orientations")

    unit_settings = build_settings(objects, info[UNIT_TEST_TARGET]["target"]["buildConfigurationList"], "Debug")
    if unit_settings.get("BUNDLE_LOADER") != "$(TEST_HOST)":
        raise Failure("unit test target must set BUNDLE_LOADER to $(TEST_HOST)")
    if APP_TARGET not in unit_settings.get("TEST_HOST", ""):
        raise Failure("unit test TEST_HOST does not point at the app binary")
    if unit_settings.get("PRODUCT_BUNDLE_IDENTIFIER") != BUNDLE_IDENTIFIERS[UNIT_TEST_TARGET]:
        raise Failure("unit test bundle identifier mismatch")

    ui_settings = build_settings(objects, info[UI_TEST_TARGET]["target"]["buildConfigurationList"], "Debug")
    if ui_settings.get("TEST_TARGET_NAME") != APP_TARGET:
        raise Failure("UI test target must set TEST_TARGET_NAME to the app target")
    if ui_settings.get("PRODUCT_BUNDLE_IDENTIFIER") != BUNDLE_IDENTIFIERS[UI_TEST_TARGET]:
        raise Failure("UI test bundle identifier mismatch")

    identifiers = [
        build_settings(objects, info[name]["target"]["buildConfigurationList"], "Debug")["PRODUCT_BUNDLE_IDENTIFIER"]
        for name in PRODUCT_TYPES
    ]
    if len(set(identifiers)) != len(identifiers):
        raise Failure("target bundle identifiers are not unique")

    notes.append("build settings, product types and test-target wiring match the Stage 01 contract")
    return notes


def check_xml(objects: dict, info: dict) -> list[str]:
    notes = []

    if not WORKSPACE_FILE.is_file():
        raise Failure("missing contents.xcworkspacedata")
    ElementTree.fromstring(WORKSPACE_FILE.read_text(encoding="utf-8"))

    if not SCHEME_FILE.is_file():
        raise Failure(f"missing shared scheme {SCHEME_FILE.name}")
    scheme = ElementTree.fromstring(SCHEME_FILE.read_text(encoding="utf-8"))
    references = scheme.findall(".//BuildableReference")
    if not references:
        raise Failure("scheme contains no BuildableReference")
    blueprint_names = set()
    for reference in references:
        blueprint = reference.get("BlueprintIdentifier")
        if blueprint not in objects:
            raise Failure(f"scheme references unknown blueprint {blueprint}")
        expected_name = objects[blueprint].get("name")
        if reference.get("BlueprintName") != expected_name:
            raise Failure(f"scheme blueprint name {reference.get('BlueprintName')!r} != target name {expected_name!r}")
        expected_product = f"{expected_name}.{'app' if expected_name == APP_TARGET else 'xctest'}"
        if reference.get("BuildableName") != expected_product:
            raise Failure(f"scheme buildable name {reference.get('BuildableName')!r} != {expected_product!r}")
        if reference.get("ReferencedContainer") != f"container:{APP_TARGET}.xcodeproj":
            raise Failure("scheme ReferencedContainer does not point at the project")
        blueprint_names.add(expected_name)

    for expected in PRODUCT_TYPES:
        if expected not in blueprint_names:
            raise Failure(f"scheme does not reference target {expected}")

    notes.append(f"shared scheme '{SCHEME_FILE.stem}' references all three targets")
    return notes


def check_asset_catalog() -> list[str]:
    catalog = PROJECT_DIR / APP_TARGET / "Resources" / "Assets.xcassets"
    files = sorted(catalog.rglob("Contents.json"))
    if not files:
        raise Failure("asset catalog has no Contents.json")
    for path in files:
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            raise Failure(f"invalid asset catalog JSON in {path.relative_to(REPO_ROOT)}: {error}") from error
    with (catalog / "Contents.json").open(encoding="utf-8") as handle:
        json.load(handle)
    if not (catalog / "AppIcon.appiconset" / "Contents.json").is_file():
        raise Failure("AppIcon.appiconset is missing")
    if not (catalog / "AccentColor.colorset" / "Contents.json").is_file():
        raise Failure("AccentColor.colorset is missing")
    return [f"asset catalog JSON valid ({len(files)} files)"]


# ---------------------------------------------------------------------- swift


def skip_string(text: str, index: int) -> int:
    index += 1
    length = len(text)
    while index < length:
        if text[index] == "\\":
            index += 2
            continue
        if text[index] == '"':
            return index + 1
        index += 1
    return length


def skip_interpolation(text: str, index: int) -> int:
    """`index` points at the '(' of a string interpolation; returns index after ')'. """
    depth = 0
    length = len(text)
    while index < length:
        char = text[index]
        if char == '"':
            index = skip_string(text, index)
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return length


def check_delimiters(text: str) -> str | None:
    pairs = {"}": "{", ")": "(", "]": "["}
    stack: list[tuple[str, int]] = []
    index, length, line = 0, len(text), 1
    in_string = False
    multiline = False

    while index < length:
        char = text[index]
        if char == "\n":
            line += 1

        if in_string:
            if multiline:
                if text.startswith('"""', index):
                    in_string = False
                    multiline = False
                    index += 3
                    continue
                index += 1
                continue
            if char == "\\":
                if text.startswith("\\(", index):
                    index = skip_interpolation(text, index + 1)
                    continue
                index += 2
                continue
            if char == '"':
                in_string = False
                index += 1
                continue
            index += 1
            continue

        if text.startswith('"""', index):
            in_string = True
            multiline = True
            index += 3
            continue
        if char == '"':
            in_string = True
            index += 1
            continue
        if text.startswith("//", index):
            end = text.find("\n", index)
            index = length if end == -1 else end
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end == -1:
                return f"unterminated block comment at line {line}"
            line += text.count("\n", index, end)
            index = end + 2
            continue

        if char in "{([":
            stack.append((char, line))
        elif char in "})]":
            if not stack:
                return f"unmatched {char!r} at line {line}"
            opener, opener_line = stack.pop()
            if opener != pairs[char]:
                return f"{char!r} at line {line} closes {opener!r} opened at line {opener_line}"
        index += 1

    if in_string:
        return "unterminated string literal"
    if stack:
        opener, opener_line = stack[-1]
        return f"unclosed {opener!r} opened at line {opener_line}"
    return None


def read_swift_files() -> dict[str, str]:
    files: dict[str, str] = {}
    for name, root in SOURCE_DIRS.items():
        for path in sorted(root.rglob("*.swift")):
            if path.is_file():
                files[str(path)] = path.read_text(encoding="utf-8")
    if not files:
        raise Failure("no Swift sources found")
    return files


def check_swift_sources(files: dict[str, str]) -> list[str]:
    for path, text in files.items():
        relative = Path(path).relative_to(REPO_ROOT)
        if "\r" in text:
            raise Failure(f"{relative} contains CR characters; use LF line endings")
        if "\t" in text:
            raise Failure(f"{relative} contains tab characters; use spaces")
        if not text.endswith("\n"):
            raise Failure(f"{relative} does not end with a newline")
        if not text.strip():
            raise Failure(f"{relative} is empty")
        problem = check_delimiters(text)
        if problem:
            raise Failure(f"{relative}: {problem}")

    total_lines = sum(text.count("\n") for text in files.values())
    return [f"{len(files)} Swift files parsed cleanly ({total_lines} lines)"]


def check_accessibility_identifiers(files: dict[str, str]) -> list[str]:
    app_text = "".join(
        text for path, text in files.items() if str(SOURCE_DIRS[APP_TARGET]) in path
    )
    declared = set(re.findall(r'accessibilityIdentifier\("([^"]+)"\)', app_text))

    ui_test_paths = [path for path in files if str(SOURCE_DIRS[UI_TEST_TARGET]) in path]
    if not ui_test_paths:
        raise Failure("no UI test sources found")
    queried: set[str] = set()
    for path in ui_test_paths:
        queried.update(re.findall(r'app\.[A-Za-z]+\["([^"]+)"\]', files[path]))

    if not queried:
        raise Failure("UI tests do not query any accessibility identifier")

    unresolved = sorted(
        identifier
        for identifier in queried
        if identifier not in declared and identifier not in SYSTEM_CONTROL_LABELS
    )
    if unresolved:
        raise Failure(
            "UI tests query identifiers the app never declares: " + ", ".join(unresolved)
        )

    notes = [
        f"{len(queried)} UI-test identifiers resolve ({', '.join(sorted(queried))}); "
        f"{len(declared)} identifiers declared in the app"
    ]
    exempt = sorted(queried & SYSTEM_CONTROL_LABELS)
    if exempt:
        notes.append(f"system-owned control labels exempt from that check: {', '.join(exempt)}")
    return notes


def main() -> int:
    notes: list[str] = []
    try:
        objects, project = parse_pbxproj()
        notes += check_referential_integrity(objects)
        notes += check_sources_on_disk(objects, project)
        wiring_notes, info = check_target_wiring(objects, project)
        notes += wiring_notes
        notes += check_build_settings(objects, project, info)
        notes += check_xml(objects, info)
        notes += check_asset_catalog()
        files = read_swift_files()
        notes += check_swift_sources(files)
        notes += check_accessibility_identifiers(files)
    except Failure as error:
        print(f"FAIL: {error}")
        return 1

    print("PASS: Stage 01 project structure verified (Xcode build/test NOT covered)")
    for note in notes:
        print(f"  - {note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

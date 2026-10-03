#!/usr/bin/env python3
"""Regenerate ``MomentsStudio.xcodeproj`` from the source tree.

Why this exists
---------------
Stage 01 was authored on a Windows host, where Xcode cannot run, so the project
file is generated deterministically from the folder layout instead of being
produced by Xcode. This keeps the project file reproducible and reviewable, and
``tools/verify_project.py`` checks the result against the sources.

Ownership rule
--------------
Until the project is opened in Xcode, this generator owns
``MomentsStudio.xcodeproj``: add or move Swift files on disk, then rerun it.
Once the team starts editing the project in Xcode (adding files, changing
signing), stop rerunning this script or it will overwrite those edits -- delete
``tools/`` at that point if it is no longer useful.

Usage
-----
    python tools/generate_xcodeproj.py
"""

from __future__ import annotations

import hashlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PROJECT_DIR = REPO_ROOT / "MomentsStudio"

APP_TARGET = "MomentsStudio"
UNIT_TEST_TARGET = "MomentsStudioTests"
UI_TEST_TARGET = "MomentsStudioUITests"

APP_SOURCE_DIR = PROJECT_DIR / APP_TARGET
UNIT_TEST_SOURCE_DIR = PROJECT_DIR / UNIT_TEST_TARGET
UI_TEST_SOURCE_DIR = PROJECT_DIR / UI_TEST_TARGET

PROJECT_FILE = PROJECT_DIR / f"{APP_TARGET}.xcodeproj"
PBXPROJ_FILE = PROJECT_FILE / "project.pbxproj"
WORKSPACE_FILE = PROJECT_FILE / "project.xcworkspace" / "contents.xcworkspacedata"
SCHEME_FILE = PROJECT_FILE / "xcshareddata" / "xcschemes" / f"{APP_TARGET}.xcscheme"

DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"
MARKETING_VERSION = "0.1.0"
CURRENT_PROJECT_VERSION = "1"
BUNDLE_ID_PREFIX = "com.example"
DEVICE_FAMILY = "1,2"
XCODE_COMPATIBILITY = "Xcode 14.0"
OBJECT_VERSION = "56"

# Directories that Xcode treats as a single file reference.
BUNDLE_SUFFIXES = {".xcassets", ".bundle", ".atlas", ".imageset", ".lproj", ".xcdatamodeld"}
RESOURCE_SUFFIXES = BUNDLE_SUFFIXES | {".plist", ".json", ".strings", ".stringsdict", ".pdf", ".png"}

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".xcassets": "folder.assetcatalog",
    ".plist": "text.plist.xml",
    ".json": "text.json",
    ".strings": "text.plist.strings",
    ".stringsdict": "text.plist.stringsdict",
    ".png": "image.png",
    ".pdf": "image.pdf",
}


def uid(*parts: str) -> str:
    """Stable 24-character uppercase identifier derived from a semantic key."""
    digest = hashlib.md5("|".join(parts).encode("utf-8")).hexdigest()
    return digest[:24].upper()


def plist_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def format_value(value, level: int = 0) -> str:
    """Format a value in the OpenStep plist dialect Xcode uses."""
    pad = "\t" * level
    if isinstance(value, dict):
        if not value:
            return "{\n" + pad + "}"
        lines = ["{"]
        for key, item in value.items():
            lines.append("\t" * (level + 1) + plist_string(key) + " = " + format_value(item, level + 1) + ";")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        if not value:
            return "(\n" + pad + ")"
        lines = ["("]
        for item in value:
            lines.append("\t" * (level + 1) + format_value(item, level + 1) + ",")
        lines.append(pad + ")")
        return "\n".join(lines)
    if isinstance(value, str):
        return plist_string(value)
    raise TypeError(f"unsupported plist value: {value!r}")


class SourceFile:
    def __init__(self, name: str, relative_path: str, suffix: str) -> None:
        self.name = name
        self.relative_path = relative_path
        self.suffix = suffix
        self.is_resource = suffix in RESOURCE_SUFFIXES
        self.file_type = FILE_TYPES.get(suffix, "text")

    @property
    def is_source(self) -> bool:
        return self.suffix == ".swift"


class SourceGroup:
    def __init__(self, name: str, relative_path: str) -> None:
        self.name = name
        self.relative_path = relative_path
        self.groups: list[SourceGroup] = []
        self.files: list[SourceFile] = []

    def walk(self):
        yield self
        for group in self.groups:
            yield from group.walk()

    def all_files(self):
        for file in self.files:
            yield file
        for group in self.groups:
            yield from group.all_files()


def scan(root: Path, relative_path: str = "") -> SourceGroup:
    """Mirror a source directory as a group tree (Xcode-style nesting)."""
    base = root / relative_path if relative_path else root
    name = base.name if relative_path else root.name
    group = SourceGroup(name, relative_path)

    for entry in sorted(base.iterdir(), key=lambda path: path.name.lower()):
        if entry.name.startswith("."):
            continue
        child_relative = f"{relative_path}/{entry.name}" if relative_path else entry.name
        if entry.is_dir() and entry.suffix.lower() not in BUNDLE_SUFFIXES:
            group.groups.append(scan(root, child_relative))
        else:
            group.files.append(SourceFile(entry.name, child_relative, entry.suffix.lower()))
    return group


PROJECT_BUILD_SETTINGS = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
    "CLANG_WARN_STRICT_PROTOTYPES": "YES",
    "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "MTL_FAST_MATH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": SWIFT_VERSION,
    "TARGETED_DEVICE_FAMILY": DEVICE_FAMILY,
}

DEBUG_ONLY_SETTINGS = {
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}

RELEASE_ONLY_SETTINGS = {
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "VALIDATE_PRODUCT": "YES",
}

APP_TARGET_SETTINGS = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": CURRENT_PROJECT_VERSION,
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "Moments Studio",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": (
        "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown "
        "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
    ),
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "MARKETING_VERSION": MARKETING_VERSION,
    "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID_PREFIX}.{APP_TARGET}",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": SWIFT_VERSION,
    "TARGETED_DEVICE_FAMILY": DEVICE_FAMILY,
}

COMMON_TEST_TARGET_SETTINGS = {
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": CURRENT_PROJECT_VERSION,
    "GENERATE_INFOPLIST_FILE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "MARKETING_VERSION": MARKETING_VERSION,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "SWIFT_VERSION": SWIFT_VERSION,
    "TARGETED_DEVICE_FAMILY": DEVICE_FAMILY,
}

UNIT_TEST_TARGET_SETTINGS = {
    **COMMON_TEST_TARGET_SETTINGS,
    "BUNDLE_LOADER": "$(TEST_HOST)",
    "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID_PREFIX}.{UNIT_TEST_TARGET}",
    "TEST_HOST": f"$(BUILT_PRODUCTS_DIR)/{APP_TARGET}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{APP_TARGET}",
}

UI_TEST_TARGET_SETTINGS = {
    **COMMON_TEST_TARGET_SETTINGS,
    "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID_PREFIX}.{UI_TEST_TARGET}",
    "TEST_TARGET_NAME": APP_TARGET,
}

TARGET_TYPES = {
    APP_TARGET: "com.apple.product-type.application",
    UNIT_TEST_TARGET: "com.apple.product-type.bundle.unit-test",
    UI_TEST_TARGET: "com.apple.product-type.bundle.ui-testing",
}

PRODUCT_FILE_TYPES = {
    APP_TARGET: "wrapper.application",
    UNIT_TEST_TARGET: "wrapper.cfbundle",
    UI_TEST_TARGET: "wrapper.cfbundle",
}


class ProjectBuilder:
    def __init__(self) -> None:
        self.app_tree = scan(APP_SOURCE_DIR)
        self.unit_test_tree = scan(UNIT_TEST_SOURCE_DIR)
        self.ui_test_tree = scan(UI_TEST_SOURCE_DIR)
        self.trees = {
            APP_TARGET: self.app_tree,
            UNIT_TEST_TARGET: self.unit_test_tree,
            UI_TEST_TARGET: self.ui_test_tree,
        }
        self.objects: dict[str, dict] = {}
        self.sections: dict[str, list[str]] = {}
        self._seen_uids: set[str] = set()
        self.group_uids: dict[tuple[str, str], str] = {}
        self.file_uids: dict[tuple[str, str], str] = {}

    # ---------------------------------------------------------------- helpers

    def register(self, identifier: str, obj: dict) -> str:
        if identifier in self.objects:
            raise SystemExit(f"duplicate object id: {identifier}")
        self.objects[identifier] = obj
        self._seen_uids.add(identifier)
        return identifier

    def add(self, section: str, identifier: str, comment: str, obj: dict) -> str:
        self.register(identifier, obj)
        self.sections.setdefault(section, []).append(
            "\t\t" + identifier + f" /* {comment} */ = " + format_value(obj, 2) + ";"
        )
        return identifier

    def group_uid(self, target: str, relative_path: str) -> str:
        return self.group_uids[(target, relative_path)]

    def file_uid(self, target: str, relative_path: str) -> str:
        return self.file_uids[(target, relative_path)]

    # ----------------------------------------------------------- scan / graph

    def validate_sources(self) -> None:
        expected = {
            APP_TARGET: APP_SOURCE_DIR,
            UNIT_TEST_TARGET: UNIT_TEST_SOURCE_DIR,
            UI_TEST_TARGET: UI_TEST_SOURCE_DIR,
        }
        for target, root in expected.items():
            if not root.is_dir():
                raise SystemExit(f"missing source directory for {target}: {root}")
            if not any(root.rglob("*.swift")):
                raise SystemExit(f"no Swift sources found for {target} in {root}")
            for file in self.trees[target].all_files():
                if not (root / file.relative_path).exists():
                    raise SystemExit(f"scanned file vanished: {root / file.relative_path}")

    def build_groups(self) -> None:
        # Target groups first: the root group lists their identifiers.
        for target, tree in self.trees.items():
            self.emit_group(target, tree)

        self.add(
            "PBXGroup",
            uid("group", "<root>"),
            "Root",
            {
                "isa": "PBXGroup",
                "children": [uid("group", target, "") for target in self.trees]
                + [uid("group", "Products")],
                "sourceTree": "<group>",
            },
        )
        self.add(
            "PBXGroup",
            uid("group", "Products"),
            "Products",
            {
                "isa": "PBXGroup",
                "children": [uid("product", target) for target in TARGET_TYPES],
                "name": "Products",
                "sourceTree": "<group>",
            },
        )

    def emit_group(self, target: str, group: SourceGroup) -> str:
        identifier = uid("group", target, group.relative_path)
        self.group_uids[(target, group.relative_path)] = identifier

        children: list[str] = []
        for child in group.groups:
            children.append(self.emit_group(target, child))
        for file in group.files:
            children.append(self.emit_file(target, file))

        self.add(
            "PBXGroup",
            identifier,
            group.relative_path or group.name,
            {
                "isa": "PBXGroup",
                "children": children,
                "path": group.name,
                "sourceTree": "<group>",
            },
        )
        return identifier

    def emit_file(self, target: str, file: SourceFile) -> str:
        identifier = uid("fileref", target, file.relative_path)
        self.file_uids[(target, file.relative_path)] = identifier
        self.add(
            "PBXFileReference",
            identifier,
            file.name,
            {
                "isa": "PBXFileReference",
                "lastKnownFileType": file.file_type,
                "path": file.name,
                "sourceTree": "<group>",
            },
        )
        return identifier

    # ------------------------------------------------------------ build graph

    def build_objects(self) -> None:
        self.validate_sources()
        self.build_groups()

        for target in TARGET_TYPES:
            product_extension = "app" if target == APP_TARGET else "xctest"
            product_name = f"{target}.{product_extension}"
            self.add(
                "PBXFileReference",
                uid("product", target),
                product_name,
                {
                    "isa": "PBXFileReference",
                    "explicitFileType": PRODUCT_FILE_TYPES[target],
                    "includeInIndex": "0",
                    "path": product_name,
                    "sourceTree": "BUILT_PRODUCTS_DIR",
                },
            )

        target_objects: dict[str, dict] = {}
        for target, tree in self.trees.items():
            source_files = [file for file in tree.all_files() if file.is_source]
            resource_files = [file for file in tree.all_files() if file.is_resource and not file.is_source]

            source_build_files = [
                self.add(
                    "PBXBuildFile",
                    uid("buildfile", target, file.relative_path),
                    f"{file.name} in Sources",
                    {"isa": "PBXBuildFile", "fileRef": self.file_uid(target, file.relative_path)},
                )
                for file in source_files
            ]
            resource_build_files = [
                self.add(
                    "PBXBuildFile",
                    uid("buildfile", target, file.relative_path),
                    f"{file.name} in Resources",
                    {"isa": "PBXBuildFile", "fileRef": self.file_uid(target, file.relative_path)},
                )
                for file in resource_files
            ]

            sources_phase = self.add(
                "PBXSourcesBuildPhase",
                uid("phase.sources", target),
                "Sources",
                {"isa": "PBXSourcesBuildPhase", "buildActionMask": "2147483647", "files": source_build_files, "runOnlyForDeploymentPostprocessing": "0"},
            )
            frameworks_phase = self.add(
                "PBXFrameworksBuildPhase",
                uid("phase.frameworks", target),
                "Frameworks",
                {"isa": "PBXFrameworksBuildPhase", "buildActionMask": "2147483647", "files": [], "runOnlyForDeploymentPostprocessing": "0"},
            )
            resources_phase = self.add(
                "PBXResourcesBuildPhase",
                uid("phase.resources", target),
                "Resources",
                {"isa": "PBXResourcesBuildPhase", "buildActionMask": "2147483647", "files": resource_build_files, "runOnlyForDeploymentPostprocessing": "0"},
            )

            dependencies: list[str] = []
            if target in (UNIT_TEST_TARGET, UI_TEST_TARGET):
                proxy = self.add(
                    "PBXContainerItemProxy",
                    uid("proxy", target),
                    "PBXContainerItemProxy",
                    {
                        "isa": "PBXContainerItemProxy",
                        "containerPortal": uid("project"),
                        "proxyType": "1",
                        "remoteGlobalIDString": uid("target", APP_TARGET),
                        "remoteInfo": APP_TARGET,
                    },
                )
                dependencies.append(
                    self.add(
                        "PBXTargetDependency",
                        uid("dep", target),
                        "PBXTargetDependency",
                        {"isa": "PBXTargetDependency", "target": uid("target", APP_TARGET), "targetProxy": proxy},
                    )
                )

            settings = {
                "Debug": self.target_settings(target, "Debug"),
                "Release": self.target_settings(target, "Release"),
            }
            configuration_list = self.add(
                "XCConfigurationList",
                uid("configlist", target),
                "Build configuration list for PBXNativeTarget " + f'"{target}"',                {
                    "isa": "XCConfigurationList",
                    "buildConfigurations": [
                        uid("config", target, name) for name in ("Debug", "Release")
                    ],
                    "defaultConfigurationIsVisible": "0",
                    "defaultConfigurationName": "Release",
                },
            )
            for name in ("Debug", "Release"):
                self.add(
                    "XCBuildConfiguration",
                    uid("config", target, name),
                    name,
                    {"isa": "XCBuildConfiguration", "buildSettings": settings[name], "name": name},
                )

            target_objects[target] = {
                "isa": "PBXNativeTarget",
                "buildConfigurationList": configuration_list,
                "buildPhases": [sources_phase, frameworks_phase, resources_phase],
                "buildRules": [],
                "dependencies": dependencies,
                "name": target,
                "productName": target,
                "productReference": uid("product", target),
                "productType": TARGET_TYPES[target],
            }

        for target, obj in target_objects.items():
            self.add("PBXNativeTarget", uid("target", target), target, obj)

        # Project-level build configurations.
        project_settings = {
            "Debug": {**PROJECT_BUILD_SETTINGS, **DEBUG_ONLY_SETTINGS},
            "Release": {**PROJECT_BUILD_SETTINGS, **RELEASE_ONLY_SETTINGS},
        }
        project_config_list = self.add(
            "XCConfigurationList",
            uid("configlist", "project"),
            "Build configuration list for PBXProject " + f'"{APP_TARGET}"',
            {
                "isa": "XCConfigurationList",
                "buildConfigurations": [uid("config", "project", name) for name in ("Debug", "Release")],
                "defaultConfigurationIsVisible": "0",
                "defaultConfigurationName": "Release",
            },
        )
        for name in ("Debug", "Release"):
            self.add(
                "XCBuildConfiguration",
                uid("config", "project", name),
                name,
                {"isa": "XCBuildConfiguration", "buildSettings": project_settings[name], "name": name},
            )

        target_attributes = {
            uid("target", APP_TARGET): {"CreatedOnToolsVersion": "15.0"},
            uid("target", UNIT_TEST_TARGET): {"CreatedOnToolsVersion": "15.0", "TestTargetID": uid("target", APP_TARGET)},
            uid("target", UI_TEST_TARGET): {"CreatedOnToolsVersion": "15.0", "TestTargetID": uid("target", APP_TARGET)},
        }
        self.add(
            "PBXProject",
            uid("project"),
            "Project object",
            {
                "isa": "PBXProject",
                "attributes": {
                    "BuildIndependentTargetsInParallel": "1",
                    "LastSwiftUpdateCheck": "1500",
                    "LastUpgradeCheck": "1500",
                    "TargetAttributes": target_attributes,
                },
                "buildConfigurationList": project_config_list,
                "compatibilityVersion": XCODE_COMPATIBILITY,
                "developmentRegion": "en",
                "hasScannedForEncodings": "0",
                "knownRegions": ["en", "Base"],
                "mainGroup": uid("group", "<root>"),
                "productRefGroup": uid("group", "Products"),
                "projectDirPath": "",
                "projectRoot": "",
                "targets": [uid("target", target) for target in TARGET_TYPES],
            },
        )

    @staticmethod
    def target_settings(target: str, configuration: str) -> dict:
        if target == APP_TARGET:
            return dict(APP_TARGET_SETTINGS)
        if target == UNIT_TEST_TARGET:
            return dict(UNIT_TEST_TARGET_SETTINGS)
        return dict(UI_TEST_TARGET_SETTINGS)

    # ------------------------------------------------------------- serialising

    def serialise(self) -> str:
        order = [
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
        ]
        known = set(order)
        unexpected = set(self.sections) - known
        if unexpected:
            raise SystemExit(f"unserialised sections: {sorted(unexpected)}")

        lines = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", f"\tobjectVersion = {OBJECT_VERSION};", "\tobjects = {"]
        for section in order:
            entries = self.sections.get(section, [])
            if not entries:
                continue
            lines.append(f"/* Begin {section} section */")
            lines.extend(entries)
            lines.append(f"/* End {section} section */")
        lines.append("\t};")
        lines.append(f'\trootObject = {uid("project")} /* Project object */;')
        lines.append("}")
        return "\n".join(lines) + "\n"

    def write(self) -> None:
        PBXPROJ_FILE.parent.mkdir(parents=True, exist_ok=True)
        PBXPROJ_FILE.write_text(self.serialise(), encoding="utf-8", newline="\n")

        WORKSPACE_FILE.parent.mkdir(parents=True, exist_ok=True)
        WORKSPACE_FILE.write_text(
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<Workspace\n   version = "1.0">\n'
            '   <FileRef\n      location = "self:">\n   </FileRef>\n'
            "</Workspace>\n",
            encoding="utf-8",
            newline="\n",
        )

        SCHEME_FILE.parent.mkdir(parents=True, exist_ok=True)
        SCHEME_FILE.write_text(self.scheme_xml(), encoding="utf-8", newline="\n")

    def scheme_xml(self) -> str:
        def reference(target: str) -> str:
            extension = "app" if target == APP_TARGET else "xctest"
            return (
                '               <BuildableReference\n'
                f'                  BuildableIdentifier = "primary"\n'
                f'                  BlueprintIdentifier = "{uid("target", target)}"\n'
                f'                  BuildableName = "{target}.{extension}"\n'
                f'                  BlueprintName = "{target}"\n'
                f'                  ReferencedContainer = "container:{APP_TARGET}.xcodeproj">\n'
                "               </BuildableReference>\n"
            )

        testables = "".join(
            '            <TestableReference\n               skipped = "NO">\n'
            + reference(target)
            + "            </TestableReference>\n"
            for target in (UNIT_TEST_TARGET, UI_TEST_TARGET)
        )

        return (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            "<Scheme\n"
            '   LastUpgradeVersion = "1500"\n'
            '   version = "1.7">\n'
            '   <BuildAction\n'
            '      parallelizeBuildables = "YES"\n'
            '      buildImplicitDependencies = "YES">\n'
            "      <BuildActionEntries>\n"
            "         <BuildActionEntry\n"
            '            buildForTesting = "YES"\n'
            '            buildForRunning = "YES"\n'
            '            buildForProfiling = "YES"\n'
            '            buildForArchiving = "YES"\n'
            '            buildForAnalyzing = "YES">\n'
            + reference(APP_TARGET)
            + "         </BuildActionEntry>\n"
            "      </BuildActionEntries>\n"
            "   </BuildAction>\n"
            '   <TestAction\n'
            '      buildConfiguration = "Debug"\n'
            '      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
            '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n'
            '      shouldUseLaunchSchemeArgsEnv = "YES"\n'
            '      shouldAutocreateTestPlan = "YES">\n'
            "      <Testables>\n"
            + testables
            + "      </Testables>\n"
            "   </TestAction>\n"
            '   <LaunchAction\n'
            '      buildConfiguration = "Debug"\n'
            '      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
            '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n'
            '      launchStyle = "0"\n'
            '      useCustomWorkingDirectory = "NO"\n'
            '      ignoresPersistentStateOnLaunch = "NO"\n'
            '      debugDocumentVersioning = "YES"\n'
            '      debugServiceExtension = "internal"\n'
            '      allowLocationSimulation = "YES">\n'
            "      <BuildableProductRunnable\n"
            '         runnableDebuggingMode = "0">\n'
            + reference(APP_TARGET)
            + "      </BuildableProductRunnable>\n"
            "   </LaunchAction>\n"
            '   <ProfileAction\n'
            '      buildConfiguration = "Release"\n'
            '      shouldUseLaunchSchemeArgsEnv = "YES"\n'
            '      savedToolIdentifier = ""\n'
            '      useCustomWorkingDirectory = "NO"\n'
            '      debugDocumentVersioning = "YES">\n'
            "      <BuildableProductRunnable\n"
            '         runnableDebuggingMode = "0">\n'
            + reference(APP_TARGET)
            + "      </BuildableProductRunnable>\n"
            "   </ProfileAction>\n"
            '   <AnalyzeAction\n'
            '      buildConfiguration = "Debug">\n'
            "   </AnalyzeAction>\n"
            '   <ArchiveAction\n'
            '      buildConfiguration = "Release"\n'
            '      revealArchiveInOrganizer = "YES">\n'
            "   </ArchiveAction>\n"
            "</Scheme>\n"
        )


def main() -> None:
    builder = ProjectBuilder()
    builder.build_objects()
    builder.write()

    counts = {target: len(list(tree.all_files())) for target, tree in builder.trees.items()}
    print(f"wrote {PBXPROJ_FILE.relative_to(REPO_ROOT)}")
    print(f"wrote {WORKSPACE_FILE.relative_to(REPO_ROOT)}")
    print(f"wrote {SCHEME_FILE.relative_to(REPO_ROOT)}")
    for target, count in counts.items():
        print(f"  {target}: {count} file references")
    print(f"  objects: {len(builder.objects)}")


if __name__ == "__main__":
    main()

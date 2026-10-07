"""Static artifact checks and mathematical spot checks. This does NOT execute Swift."""
from pathlib import Path
import json
import plistlib
import re
import xml.etree.ElementTree as ET
import hashlib

ROOT = Path(__file__).resolve().parents[1]
checks = 0


def check(condition, message):
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1


def plist(path):
    with (ROOT / path).open("rb") as file:
        return plistlib.load(file)


info = plist("Config/Info.plist")
check(info["WKWatchOnly"] and info["WKApplication"], "Not configured watch-only")
check("WKRunsIndependentlyOfCompanionApp" not in info, "Watch-only app must not also define the companion independence key")
check(bool(info["NSHealthShareUsageDescription"]), "Read usage description missing")
check("WKCompanionAppBundleIdentifier" not in info, "Unexpected iOS dependency")
check(plist("Config/Aevum.entitlements")["com.apple.developer.healthkit"], "HealthKit entitlement missing")
privacy = plist("App/PrivacyInfo.xcprivacy")
check(privacy["NSPrivacyTracking"] is False, "Unexpected tracking")
check(privacy["NSPrivacyCollectedDataTypes"] == [], "Unexpected data collection")

swift_files = sorted((ROOT / "App").rglob("*.swift"))
app = "\n".join(path.read_text(encoding="utf-8") for path in swift_files)
check(len(re.findall(r"@main\b", app)) == 1, "Exactly one entry point required")
for forbidden in ["URLSession", "WCSession", "import UIKit", "UserDefaults", "HKWorkoutSession"]:
    check(forbidden not in app, f"Unexpected dependency: {forbidden}")
check("toShare: []" in app, "Read-only authorization missing")
check("#if DEBUG\nimport Foundation" in (ROOT / "App/Model/DemoData.swift").read_text(), "Demo not debug-only")
check(".privacySensitive()" in app, "Health screen privacy marking missing")
check(".completeFileProtection" in app, "Settings file protection missing")

source = (ROOT / "Core/Sources/BodyAgeCore/FitnessAge.swift").read_text(encoding="utf-8")
tables = {}
for name, expected in {
    "maleMedians": [48.0, 42.4, 37.8, 32.6, 28.2, 24.4],
    "femaleMedians": [37.6, 30.2, 26.7, 23.4, 20.0, 18.3],
    "ages": [24.5, 34.5, 44.5, 54.5, 64.5, 74.5],
}.items():
    match = re.search(rf"let {name} = (\[[^\]]+\])", source)
    check(match is not None, f"Missing table {name}")
    tables[name] = json.loads(match.group(1))
    check(tables[name] == expected, f"Published constants differ: {name}")


def reference_age(x, medians):
    """Independent math check of the specified mapping, not a Swift execution."""
    ages = tables["ages"]
    if x > medians[0]:
        return ages[0]
    if x < medians[-1]:
        return ages[-1]
    for i in range(len(medians) - 1):
        if medians[i] >= x >= medians[i + 1]:
            return ages[i] + 10 * (medians[i] - x) / (medians[i] - medians[i + 1])
    raise AssertionError("No mapping")


check(abs(reference_age(40.1, tables["maleMedians"]) - 39.5) < 1e-10, "Male midpoint mismatch")
check(abs(reference_age(28.45, tables["femaleMedians"]) - 39.5) < 1e-10, "Female midpoint mismatch")
for name in ["maleMedians", "femaleMedians"]:
    mapped = [reference_age(i / 10, tables[name]) for i in range(140, 651)]
    check(all(a >= b for a, b in zip(mapped, mapped[1:])), "Non-monotone reference mapping")

project = (ROOT / "Aevum.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
definitions = set(re.findall(r'"([A-F0-9]{24})" = \{', project))
references = set(re.findall(r'\b[A-F0-9]{24}\b', project))
check(references <= definitions, "Dangling project object reference")
check(project.count('"isa" = "PBXNativeTarget"') == 1, "Expected one native target")
check('"SDKROOT" = "watchos"' in project, "watchOS SDK missing")
check("XCLocalSwiftPackageReference" not in project, "Unexpected local package dependency")
check("XCSwiftPackageProductDependency" not in project, "Unexpected package product dependency")
check("import BodyAgeCore" not in app, "App must use its directly compiled core types")
core_files = sorted((ROOT / "Core/Sources/BodyAgeCore").glob("*.swift"))
check(len(core_files) == 5, "Expected five directly compiled core source files")
sources_phase = re.search(r'"isa" = "PBXSourcesBuildPhase";.*?"files" = \(([^)]*)\)', project, re.S).group(1)
for path in swift_files + core_files:
    relative = path.relative_to(ROOT).as_posix()
    check(project.count(f'"path" = "{relative}"') == 1, f"Source not present exactly once: {relative}")
    build_id = hashlib.sha256(("build:" + relative).encode()).hexdigest()[:24].upper()
    check(sources_phase.count(build_id) == 1, f"Source not compiled exactly once: {relative}")
check(len(re.findall(r'\b[A-F0-9]{24}\b', sources_phase)) == 16, "Compile phase must contain only the 16 app/core files")
check('"path" = "Core/Package.swift"' not in project, "Package manifest must not be compiled in the app")
check('"path" = "Core/Tests/' not in project, "XCTest sources must not be compiled in the app")
scheme = ET.parse(ROOT / "Aevum.xcodeproj/xcshareddata/xcschemes/Aevum.xcscheme")
check(all(item.attrib["BlueprintIdentifier"] in definitions for item in scheme.iter("BuildableReference")), "Invalid scheme target")
test_source = (ROOT / "Core/Tests/BodyAgeCoreTests/BodyAgeCoreTests.swift").read_text(encoding="utf-8")
tests = len(re.findall(r"func test\w+\(", test_source))
check(tests >= 24, "Core regression test inventory incomplete")
root_view = (ROOT / "App/Views/RootView.swift").read_text(encoding="utf-8")
check("TabView" not in root_view, "Old dense paged root still present")
check("NavigationStack(path: $path)" in root_view, "Typed click navigation missing")
check("accessibilityReduceMotion" in app, "Reduce Motion support missing")
check("repeatForever" not in app, "Unexpected continuous animation")
check("AgePresentation(position:" in app, "Signed age difference not connected")
check((ROOT / "Core/Sources/BodyAgeCore/AgePresentation.swift").is_file(), "Presentation model missing")
check('INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp' not in project, "Conflicting watch flag injected")
for path in ["README.md", "Docs/SCIENCE.md", "Docs/VALIDATION.md"]:
    check((ROOT / path).is_file(), f"Missing documentation: {path}")
print(f"PASS: {checks} static/specification checks; {len(swift_files)} app Swift files; {tests} Swift test methods present.")
print("Swift compilation, XCTest execution, watchOS UI and HealthKit runtime validation: NOT RUN by this script.")

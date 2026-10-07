"""Rebuild the minimal, dependency-free watchOS Xcode project (Python 3.9+).

This writes only Aevum.xcodeproj/project.pbxproj and its shared Aevum scheme.
It does not touch source, personal signing settings in other projects, or health data.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
objects = {}


class Ref(str):
    pass


def ident(key):
    return Ref(hashlib.sha256(key.encode()).hexdigest()[:24].upper())


def add(key, **values):
    key = ident(key)
    objects[key] = values
    return key


def encode(value, level=0):
    if isinstance(value, Ref):
        return value
    if isinstance(value, dict):
        lines = ["{"]
        for k, v in value.items():
            lines.append("\t" * (level + 1) + json.dumps(k) + " = " + encode(v, level + 1) + ";")
        lines.append("\t" * level + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        return "(" + ", ".join(encode(v, level) for v in value) + ("," if value else "") + ")"
    if isinstance(value, int):
        return str(value)
    return json.dumps(value, ensure_ascii=False)


def generate():
    project_id = ident("project")
    target_id = ident("target")
    source_refs, core_refs, builds = [], [], []
    swift_files = sorted((ROOT / "App").rglob("*.swift")) + sorted((ROOT / "Core/Sources/BodyAgeCore").glob("*.swift"))
    for source in swift_files:
        path = source.relative_to(ROOT).as_posix()
        ref = add(path, isa="PBXFileReference", lastKnownFileType="sourcecode.swift",
                  path=path, sourceTree="<group>")
        (core_refs if path.startswith("Core/") else source_refs).append(ref)
        builds.append(add("build:" + path, isa="PBXBuildFile", fileRef=ref))
    privacy = add("privacy", isa="PBXFileReference", lastKnownFileType="text.xml",
                  path="App/PrivacyInfo.xcprivacy", sourceTree="<group>")
    privacy_build = add("privacy-build", isa="PBXBuildFile", fileRef=privacy)
    other_refs = []
    for path in ["Config/Info.plist", "Config/Aevum.entitlements", "README.md",
                 "Docs/SCIENCE.md", "Docs/VALIDATION.md"]:
        other_refs.append(add(path, isa="PBXFileReference", path=path, sourceTree="<group>",
            lastKnownFileType="text.plist.xml" if path.endswith(("plist", "entitlements")) else "net.daringfireball.markdown"))
    product = add("product", isa="PBXFileReference", explicitFileType="wrapper.application",
                  includeInIndex=0, path="Aevum.app", sourceTree="BUILT_PRODUCTS_DIR")
    app_group = add("app-group", isa="PBXGroup", children=source_refs + [privacy], name="App", sourceTree="<group>")
    core_group = add("core-group", isa="PBXGroup", children=core_refs, name="Core Sources", sourceTree="<group>")
    product_group = add("products", isa="PBXGroup", children=[product], name="Products", sourceTree="<group>")
    group = add("root", isa="PBXGroup", children=[app_group, core_group] + other_refs + [product_group], sourceTree="<group>")
    sources = add("sources", isa="PBXSourcesBuildPhase", buildActionMask=2147483647,
                  files=builds, runOnlyForDeploymentPostprocessing=0)
    resources = add("resources", isa="PBXResourcesBuildPhase", buildActionMask=2147483647,
                    files=[privacy_build], runOnlyForDeploymentPostprocessing=0)
    frameworks = add("frameworks", isa="PBXFrameworksBuildPhase", buildActionMask=2147483647,
                     files=[], runOnlyForDeploymentPostprocessing=0)
    project_configs, target_configs = [], []
    for name in ["Debug", "Release"]:
        debug = name == "Debug"
        settings = dict(ALWAYS_SEARCH_USER_PATHS="NO", CLANG_ENABLE_MODULES="YES", CLANG_ENABLE_OBJC_ARC="YES",
            SDKROOT="watchos", WATCHOS_DEPLOYMENT_TARGET="10.0", SWIFT_VERSION="5.0",
            SWIFT_STRICT_CONCURRENCY="minimal", DEBUG_INFORMATION_FORMAT="dwarf" if debug else "dwarf-with-dsym",
            SWIFT_OPTIMIZATION_LEVEL="-Onone" if debug else "-O", ENABLE_TESTABILITY="YES" if debug else "NO",
            SWIFT_ACTIVE_COMPILATION_CONDITIONS="$(inherited) DEBUG" if debug else "$(inherited)")
        project_configs.append(add("project:" + name, isa="XCBuildConfiguration", buildSettings=settings, name=name))
        target_settings = dict(PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="com.example.Aevum.watchapp",
            CODE_SIGN_STYLE="Automatic", CODE_SIGN_ENTITLEMENTS="Config/Aevum.entitlements",
            GENERATE_INFOPLIST_FILE="NO", INFOPLIST_FILE="Config/Info.plist", TARGETED_DEVICE_FAMILY="4",
            SUPPORTED_PLATFORMS="watchos watchsimulator", SKIP_INSTALL="NO",
            LD_RUNPATH_SEARCH_PATHS=["$(inherited)", "@executable_path/Frameworks"],
            MARKETING_VERSION="1.0", CURRENT_PROJECT_VERSION="1")
        target_configs.append(add("target:" + name, isa="XCBuildConfiguration", buildSettings=target_settings, name=name))
    project_list = add("project-configs", isa="XCConfigurationList", buildConfigurations=project_configs,
                       defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
    target_list = add("target-configs", isa="XCConfigurationList", buildConfigurations=target_configs,
                      defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
    objects[target_id] = dict(isa="PBXNativeTarget", buildConfigurationList=target_list,
        buildPhases=[sources, frameworks, resources], buildRules=[], dependencies=[], name="Aevum",
        packageProductDependencies=[], productName="Aevum", productReference=product,
        productType="com.apple.product-type.application")
    objects[project_id] = dict(isa="PBXProject", attributes={"LastUpgradeCheck": "1500",
        "TargetAttributes": {target_id: {"CreatedOnToolsVersion": "15.0", "SystemCapabilities": {
            "com.apple.HealthKit": {"enabled": 1}}}}}, buildConfigurationList=project_list,
        compatibilityVersion="Xcode 14.0", developmentRegion="zh-Hans", hasScannedForEncodings=0,
        knownRegions=["zh-Hans", "en", "Base"], mainGroup=group, packageReferences=[],
        productRefGroup=product_group, projectDirPath="", projectRoot="", targets=[target_id])
    project = ROOT / "Aevum.xcodeproj"
    project.mkdir(exist_ok=True)
    data = dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=project_id)
    (project / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode(data) + "\n", encoding="utf-8")
    schemes = project / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="Aevum.app" BlueprintName="Aevum" ReferencedContainer="container:Aevum.xcodeproj"/>'
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (schemes / "Aevum.xcscheme").write_text(scheme, encoding="utf-8")
    print(f"Generated {project.name}: {len(source_refs)} app + {len(core_refs)} core Swift files, one watchOS target, no package link dependency.")


if __name__ == "__main__":
    generate()

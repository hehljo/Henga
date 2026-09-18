import os
import hashlib

def make_id(key: str) -> str:
    return hashlib.md5(key.encode('utf-8')).hexdigest()[:24].upper()

def main():
    root_dir = "/SynologyMount"
    proj_dir = os.path.join(root_dir, "SynologyMount.xcodeproj")
    os.makedirs(proj_dir, exist_ok=True)
    shared_data = os.path.join(proj_dir, "xcshareddata", "xcschemes")
    os.makedirs(shared_data, exist_ok=True)
    
    core_files = []
    mac_files = []
    
    for r, _, fnames in os.walk(os.path.join(root_dir, "Sources/SynologyMountCore")):
        for f in sorted(fnames):
            if f.endswith(".swift"):
                rel = os.path.relpath(os.path.join(r, f), root_dir)
                core_files.append(rel)
                
    for r, _, fnames in os.walk(os.path.join(root_dir, "Sources/SynologyMountMac")):
        for f in sorted(fnames):
            if f.endswith(".swift"):
                rel = os.path.relpath(os.path.join(r, f), root_dir)
                mac_files.append(rel)

    entitlements_rel = "Sources/SynologyMountMac/App.entitlements"
    info_plist_rel = "Sources/SynologyMountMac/Info.plist"
    assets_rel = "Sources/SynologyMountMac/Assets.xcassets"
    strings_rel = "Sources/SynologyMountMac/Localizable.xcstrings"
    
    all_swift_files = sorted(core_files + mac_files)
    
    # PBX IDs
    PROJ_ID = make_id("PROJECT_ROOT_SYNO_MOUNT")
    TARGET_ID = make_id("TARGET_MACOS_APP_SYNO_MOUNT")
    SOURCES_PHASE_ID = make_id("PHASE_SOURCES_SYNO_MOUNT")
    FRAMEWORKS_PHASE_ID = make_id("PHASE_FRAMEWORKS_SYNO_MOUNT")
    RESOURCES_PHASE_ID = make_id("PHASE_RESOURCES_SYNO_MOUNT")
    APP_PRODUCT_ID = make_id("PRODUCT_APP_SYNO_MOUNT")
    
    MAIN_GROUP_ID = make_id("GROUP_MAIN_SYNO_MOUNT")
    SOURCES_GROUP_ID = make_id("GROUP_SOURCES_SYNO_MOUNT")
    CORE_GROUP_ID = make_id("GROUP_CORE_SYNO_MOUNT")
    MAC_GROUP_ID = make_id("GROUP_MAC_SYNO_MOUNT")
    PRODUCTS_GROUP_ID = make_id("GROUP_PRODUCTS_SYNO_MOUNT")
    
    PROJ_CONFIG_LIST_ID = make_id("CONFIG_LIST_PROJECT_SYNO_MOUNT")
    PROJ_DEBUG_CONFIG_ID = make_id("CONFIG_PROJECT_DEBUG_SYNO_MOUNT")
    PROJ_RELEASE_CONFIG_ID = make_id("CONFIG_PROJECT_RELEASE_SYNO_MOUNT")
    
    TARGET_CONFIG_LIST_ID = make_id("CONFIG_LIST_TARGET_SYNO_MOUNT")
    TARGET_DEBUG_CONFIG_ID = make_id("CONFIG_TARGET_DEBUG_SYNO_MOUNT")
    TARGET_RELEASE_CONFIG_ID = make_id("CONFIG_TARGET_RELEASE_SYNO_MOUNT")
    
    # File References & Build Files
    file_refs = {}
    build_files = {}
    
    for fpath in all_swift_files:
        fid = make_id(f"file_ref_{fpath}")
        bid = make_id(f"build_file_{fpath}")
        file_refs[fpath] = (fid, bid)
        build_files[bid] = (fid, os.path.basename(fpath))
        
    ent_fid = make_id("file_ref_entitlements_sm")
    plist_fid = make_id("file_ref_infoplist_sm")
    assets_fid = make_id("file_ref_assets_sm")
    assets_bid = make_id("build_file_assets_sm")
    strings_fid = make_id("file_ref_strings_sm")
    strings_bid = make_id("build_file_strings_sm")
    
    lines = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tclasses = {")
    lines.append("\t};")
    lines.append("\tobjectVersion = 56;")
    lines.append("\tobjects = {")
    lines.append("")
    
    # PBXBuildFile
    lines.append("/* Begin PBXBuildFile section */")
    for fpath in all_swift_files:
        fid, bid = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t{bid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fname} */; }};")
    lines.append(f"\t\t{assets_bid} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_fid} /* Assets.xcassets */; }};")
    lines.append(f"\t\t{strings_bid} /* Localizable.xcstrings in Resources */ = {{isa = PBXBuildFile; fileRef = {strings_fid} /* Localizable.xcstrings */; }};")
    lines.append("/* End PBXBuildFile section */")
    lines.append("")
    
    # PBXFileReference
    lines.append("/* Begin PBXFileReference section */")
    lines.append(f"\t\t{APP_PRODUCT_ID} /* SynologyMount.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SynologyMount.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    lines.append(f"\t\t{ent_fid} /* App.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; name = \"App.entitlements\"; path = \"{entitlements_rel}\"; sourceTree = SOURCE_ROOT; }};")
    lines.append(f"\t\t{plist_fid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = \"Info.plist\"; path = \"{info_plist_rel}\"; sourceTree = SOURCE_ROOT; }};")
    lines.append(f"\t\t{assets_fid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = \"Assets.xcassets\"; path = \"{assets_rel}\"; sourceTree = SOURCE_ROOT; }};")
    lines.append(f"\t\t{strings_fid} /* Localizable.xcstrings */ = {{isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; name = \"Localizable.xcstrings\"; path = \"{strings_rel}\"; sourceTree = SOURCE_ROOT; }};")
    for fpath in all_swift_files:
        fid, _ = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = \"{fname}\"; path = \"{fpath}\"; sourceTree = SOURCE_ROOT; }};")
    lines.append("/* End PBXFileReference section */")
    lines.append("")
    
    # PBXFrameworksBuildPhase
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    lines.append(f"\t\t{FRAMEWORKS_PHASE_ID} /* Frameworks */ = {{")
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXFrameworksBuildPhase section */")
    lines.append("")
    
    # PBXGroup
    lines.append("/* Begin PBXGroup section */")
    lines.append(f"\t\t{MAIN_GROUP_ID} = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{CORE_GROUP_ID} /* SynologyMountCore */,")
    lines.append(f"\t\t\t\t{MAC_GROUP_ID} /* SynologyMountMac */,")
    lines.append(f"\t\t\t\t{PRODUCTS_GROUP_ID} /* Products */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{CORE_GROUP_ID} /* SynologyMountCore */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for fpath in core_files:
        fid, _ = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t\t\t{fid} /* {fname} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = SynologyMountCore;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{MAC_GROUP_ID} /* SynologyMountMac */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for fpath in mac_files:
        fid, _ = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t\t\t{fid} /* {fname} */,")
    lines.append(f"\t\t\t\t{ent_fid} /* App.entitlements */,")
    lines.append(f"\t\t\t\t{plist_fid} /* Info.plist */,")
    lines.append(f"\t\t\t\t{assets_fid} /* Assets.xcassets */,")
    lines.append(f"\t\t\t\t{strings_fid} /* Localizable.xcstrings */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = SynologyMountMac;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{PRODUCTS_GROUP_ID} /* Products */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{APP_PRODUCT_ID} /* SynologyMount.app */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("/* End PBXGroup section */")
    lines.append("")
    
    # PBXNativeTarget
    lines.append("/* Begin PBXNativeTarget section */")
    lines.append(f"\t\t{TARGET_ID} /* SynologyMount */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {TARGET_CONFIG_LIST_ID} /* Build configuration list for PBXNativeTarget \"SynologyMount\" */;")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{SOURCES_PHASE_ID} /* Sources */,")
    lines.append(f"\t\t\t\t{FRAMEWORKS_PHASE_ID} /* Frameworks */,")
    lines.append(f"\t\t\t\t{RESOURCES_PHASE_ID} /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdependencies = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = SynologyMount;")
    lines.append("\t\t\tproductName = SynologyMount;")
    lines.append(f"\t\t\tproductReference = {APP_PRODUCT_ID} /* SynologyMount.app */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */")
    lines.append("")
    
    # PBXProject
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{PROJ_ID} /* Project object */ = {{")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {")
    lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    lines.append("\t\t\t\tLastUpgradeCheck = 1600;")
    lines.append("\t\t\t\tTargetAttributes = {")
    lines.append(f"\t\t\t\t\t{TARGET_ID} = {{")
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    lines.append("\t\t\t\t\t};")
    lines.append("\t\t\t\t};")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tbuildConfigurationList = {PROJ_CONFIG_LIST_ID} /* Build configuration list for PBXProject \"SynologyMount\" */;")
    lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append("\t\t\tdevelopmentRegion = de;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (")
    lines.append("\t\t\t\tde,")
    lines.append("\t\t\t\ten,")
    lines.append("\t\t\t\tBase,")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tmainGroup = {MAIN_GROUP_ID};")
    lines.append(f"\t\t\tproductRefGroup = {PRODUCTS_GROUP_ID} /* Products */;")
    lines.append("\t\t\tprojectDirPath = \"\";")
    lines.append("\t\t\tprojectRoot = \"\";")
    lines.append("\t\t\ttargets = (")
    lines.append(f"\t\t\t\t{TARGET_ID} /* SynologyMount */,")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("/* End PBXProject section */")
    lines.append("")
    
    # PBXResourcesBuildPhase
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{RESOURCES_PHASE_ID} /* Resources */ = {{")
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append(f"\t\t\t\t{assets_bid} /* Assets.xcassets in Resources */,")
    lines.append(f"\t\t\t\t{strings_bid} /* Localizable.xcstrings in Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXResourcesBuildPhase section */")
    lines.append("")
    
    # PBXSourcesBuildPhase
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    lines.append(f"\t\t{SOURCES_PHASE_ID} /* Sources */ = {{")
    lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for fpath in all_swift_files:
        _, bid = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t\t\t{bid} /* {fname} in Sources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXSourcesBuildPhase section */")
    lines.append("")
    
    # XCBuildConfiguration
    lines.append("/* Begin XCBuildConfiguration section */")
    lines.append(f"\t\t{PROJ_DEBUG_CONFIG_ID} /* Debug */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    lines.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    lines.append("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
    lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    lines.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    lines.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
    lines.append("\t\t\t\tENABLE_TESTABILITY = YES;")
    lines.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
    lines.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    lines.append("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
    lines.append("\t\t\t\t\t\"DEBUG=1\",")
    lines.append("\t\t\t\t\t\"$(inherited)\",")
    lines.append("\t\t\t\t);")
    lines.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
    lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
    lines.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
    lines.append("\t\t\t\tSDKROOT = macosx;")
    lines.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
    lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Debug;")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{PROJ_RELEASE_CONFIG_ID} /* Release */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    lines.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    lines.append("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
    lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    lines.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    lines.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
    lines.append("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
    lines.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;")
    lines.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
    lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
    lines.append("\t\t\t\tSDKROOT = macosx;")
    lines.append("\t\t\t\tSWIFT_COMPILATION_MODE = \"wholemodule\";")
    lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Release;")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{TARGET_DEBUG_CONFIG_ID} /* Debug */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    lines.append("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
    lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    lines.append("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    lines.append("\t\t\t\tENABLE_HARDENED_RUNTIME = NO;")
    lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    lines.append("\t\t\t\tINFOPLIST_FILE = \"Sources/SynologyMountMac/Info.plist\";")
    lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    lines.append("\t\t\t\t\t\"$(inherited)\",")
    lines.append("\t\t\t\t\t\"@executable_path/../Frameworks\",")
    lines.append("\t\t\t\t);")
    lines.append("\t\t\t\tMARKETING_VERSION = 1.0;")
    lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = de.condriano.SynologyMount;")
    lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    lines.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Debug;")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{TARGET_RELEASE_CONFIG_ID} /* Release */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    lines.append("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
    lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    lines.append("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    lines.append("\t\t\t\tENABLE_HARDENED_RUNTIME = NO;")
    lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    lines.append("\t\t\t\tINFOPLIST_FILE = \"Sources/SynologyMountMac/Info.plist\";")
    lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    lines.append("\t\t\t\t\t\"$(inherited)\",")
    lines.append("\t\t\t\t\t\"@executable_path/../Frameworks\",")
    lines.append("\t\t\t\t);")
    lines.append("\t\t\t\tMARKETING_VERSION = 1.0;")
    lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = de.condriano.SynologyMount;")
    lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    lines.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Release;")
    lines.append("\t\t};")
    lines.append("/* End XCBuildConfiguration section */")
    lines.append("")
    
    # XCConfigurationList
    lines.append("/* Begin XCConfigurationList section */")
    lines.append(f"\t\t{PROJ_CONFIG_LIST_ID} /* Build configuration list for PBXProject \"SynologyMount\" */ = {{")
    lines.append("\t\t\tisa = XCConfigurationList;")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{PROJ_DEBUG_CONFIG_ID} /* Debug */,")
    lines.append(f"\t\t\t\t{PROJ_RELEASE_CONFIG_ID} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{TARGET_CONFIG_LIST_ID} /* Build configuration list for PBXNativeTarget \"SynologyMount\" */ = {{")
    lines.append("\t\t\tisa = XCConfigurationList;")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{TARGET_DEBUG_CONFIG_ID} /* Debug */,")
    lines.append(f"\t\t\t\t{TARGET_RELEASE_CONFIG_ID} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    lines.append("/* End XCConfigurationList section */")
    lines.append("")
    
    lines.append("\t};")
    lines.append(f"\trootObject = {PROJ_ID} /* Project object */;")
    lines.append("}")
    
    pbxproj_path = os.path.join(proj_dir, "project.pbxproj")
    with open(pbxproj_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Generated {pbxproj_path}")
    
    # Create Shared Scheme
    scheme_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{TARGET_ID}"
               BuildableName = "SynologyMount.app"
               BlueprintName = "SynologyMount"
               ReferencedContainer = "container:SynologyMount.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{TARGET_ID}"
            BuildableName = "SynologyMount.app"
            BlueprintName = "SynologyMount"
            ReferencedContainer = "container:SynologyMount.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{TARGET_ID}"
            BuildableName = "SynologyMount.app"
            BlueprintName = "SynologyMount"
            ReferencedContainer = "container:SynologyMount.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    scheme_path = os.path.join(shared_data, "SynologyMount.xcscheme")
    with open(scheme_path, "w", encoding="utf-8") as f:
        f.write(scheme_content)
    print(f"Generated {scheme_path}")

if __name__ == "__main__":
    main()

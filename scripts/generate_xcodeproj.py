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
    
    # Collect source files
    core_files = []
    mac_files = []
    
    for r, _, files in os.walk(os.path.join(root_dir, "Sources", "SynologyMountCore")):
        for f in files:
            if f.endswith(".swift"):
                core_files.append(os.path.relpath(os.path.join(r, f), root_dir))
                
    for r, _, files in os.walk(os.path.join(root_dir, "Sources", "SynologyMountMac")):
        for f in files:
            if f.endswith(".swift"):
                mac_files.append(os.path.relpath(os.path.join(r, f), root_dir))
                
    all_swift_files = sorted(core_files + mac_files)
    
    # File references
    file_refs = {}
    for fpath in all_swift_files:
        fid = make_id(f"file_ref_{fpath}")
        bid = make_id(f"build_file_{fpath}")
        file_refs[fpath] = (fid, bid)
        
    res_files = [
        "Sources/SynologyMountMac/Assets.xcassets",
        "Sources/SynologyMountMac/Localizable.xcstrings",
        "Sources/SynologyMountMac/Info.plist",
        "Sources/SynologyMountMac/App.entitlements"
    ]
    res_refs = {}
    for rpath in res_files:
        fid = make_id(f"file_ref_{rpath}")
        bid = make_id(f"build_file_{rpath}")
        res_refs[rpath] = (fid, bid)

    TARGET_ID = make_id("target_SynologyMount")
    PROJECT_ID = make_id("project_SynologyMount")
    MAIN_GROUP_ID = make_id("main_group")
    CORE_GROUP_ID = make_id("core_group")
    MAC_GROUP_ID = make_id("mac_group")
    PRODUCTS_GROUP_ID = make_id("products_group")
    PRODUCT_REF_ID = make_id("product_app_ref")
    
    SOURCES_PHASE_ID = make_id("sources_phase")
    RESOURCES_PHASE_ID = make_id("resources_phase")
    FRAMEWORKS_PHASE_ID = make_id("frameworks_phase")
    
    PROJ_DEBUG_CONFIG_ID = make_id("proj_debug_config")
    PROJ_RELEASE_CONFIG_ID = make_id("proj_release_config")
    TARGET_DEBUG_CONFIG_ID = make_id("target_debug_config")
    TARGET_RELEASE_CONFIG_ID = make_id("target_release_config")
    
    PROJ_CONFIG_LIST_ID = make_id("proj_config_list")
    TARGET_CONFIG_LIST_ID = make_id("target_config_list")

    lines = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tclasses = {")
    lines.append("\t};")
    lines.append("\tobjectVersion = 56;")
    lines.append("\tobjects = {")
    
    # PBXBuildFile
    lines.append("/* Begin PBXBuildFile section */")
    for fpath in all_swift_files:
        fid, bid = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t{bid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fname} */; }};")
    for rpath in ["Sources/SynologyMountMac/Assets.xcassets", "Sources/SynologyMountMac/Localizable.xcstrings"]:
        fid, bid = res_refs[rpath]
        fname = os.path.basename(rpath)
        lines.append(f"\t\t{bid} /* {fname} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fname} */; }};")
    lines.append("/* End PBXBuildFile section */")
    
    # PBXFileReference
    lines.append("/* Begin PBXFileReference section */")
    lines.append(f"\t\t{PRODUCT_REF_ID} /* SynologyMount.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SynologyMount.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for fpath in all_swift_files:
        fid, _ = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = \"{fname}\"; path = \"{fpath}\"; sourceTree = SOURCE_ROOT; }};")
    for rpath in res_files:
        fid, _ = res_refs[rpath]
        fname = os.path.basename(rpath)
        ftype = "folder.assetcatalog" if rpath.endswith(".xcassets") else ("text.plist.strings" if rpath.endswith(".xcstrings") else "text.plist.xml")
        lines.append(f"\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; name = \"{fname}\"; path = \"{rpath}\"; sourceTree = SOURCE_ROOT; }};")
    lines.append("/* End PBXFileReference section */")
    
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
    
    # PBXGroup section
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
    for fpath in sorted(core_files):
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
    for fpath in sorted(mac_files):
        fid, _ = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t\t\t{fid} /* {fname} */,")
    for rpath in res_files:
        fid, _ = res_refs[rpath]
        fname = os.path.basename(rpath)
        lines.append(f"\t\t\t\t{fid} /* {fname} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = SynologyMountMac;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{PRODUCTS_GROUP_ID} /* Products */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{PRODUCT_REF_ID} /* SynologyMount.app */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("/* End PBXGroup section */")
    
    # PBXNativeTarget section
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
    lines.append(f"\t\t\tproductReference = {PRODUCT_REF_ID} /* SynologyMount.app */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */")
    
    # PBXProject section
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{PROJECT_ID} /* Project object */ = {{")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {")
    lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    lines.append("\t\t\t\tLastUpgradeCheck = 1600;")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tbuildConfigurationList = {PROJ_CONFIG_LIST_ID} /* Build configuration list for PBXProject \"SynologyMount\" */;")
    lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append("\t\t\tdevelopmentRegion = de;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (")
    lines.append("\t\t\t\tde,")
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
    
    # PBXResourcesBuildPhase section
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{RESOURCES_PHASE_ID} /* Resources */ = {{")
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for rpath in ["Sources/SynologyMountMac/Assets.xcassets", "Sources/SynologyMountMac/Localizable.xcstrings"]:
        _, bid = res_refs[rpath]
        fname = os.path.basename(rpath)
        lines.append(f"\t\t\t\t{bid} /* {fname} in Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXResourcesBuildPhase section */")
    
    # PBXSourcesBuildPhase section
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
    
    # XCBuildConfiguration section
    lines.append("/* Begin XCBuildConfiguration section */")
    lines.append(f"\t\t{PROJ_DEBUG_CONFIG_ID} /* Debug */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    lines.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
    lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    lines.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    lines.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
    lines.append("\t\t\t\tENABLE_TESTABILITY = YES;")
    lines.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
    lines.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
    lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
    lines.append("\t\t\t\tSDKROOT = macosx;")
    lines.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
    lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Debug;")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{PROJ_RELEASE_CONFIG_ID} /* Release */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    lines.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
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
    
    for cid, cname in [(TARGET_DEBUG_CONFIG_ID, "Debug"), (TARGET_RELEASE_CONFIG_ID, "Release")]:
        lines.append(f"\t\t{cid} /* {cname} */ = {{")
        lines.append("\t\t\tisa = XCBuildConfiguration;")
        lines.append("\t\t\tbuildSettings = {")
        lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        lines.append("\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"Sources/SynologyMountMac/App.entitlements\";")
        lines.append("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
        lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        lines.append("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
        lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        lines.append("\t\t\t\tENABLE_HARDENED_RUNTIME = YES;")
        lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
        lines.append("\t\t\t\tINFOPLIST_FILE = \"Sources/SynologyMountMac/Info.plist\";")
        lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
        lines.append("\t\t\t\t\t\"$(inherited)\",")
        lines.append("\t\t\t\t\t\"@executable_path/../Frameworks\",")
        lines.append("\t\t\t\t);")
        lines.append("\t\t\t\tMARKETING_VERSION = 1.0;")
        lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.hehljo.SynologyMount;")
        lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        lines.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
        lines.append("\t\t\t};")
        lines.append(f"\t\t\tname = {cname};")
        lines.append("\t\t};")
    lines.append("/* End XCBuildConfiguration section */")
    
    # XCConfigurationList section
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
    
    lines.append("\t};")
    lines.append(f"\trootObject = {PROJECT_ID} /* Project object */;")
    lines.append("}")
    
    with open(os.path.join(proj_dir, "project.pbxproj"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
        
    print(f"Generated {os.path.join(proj_dir, 'project.pbxproj')}")

if __name__ == "__main__":
    main()

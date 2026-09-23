import os
import re
import sys
import hashlib

# Build-Settings je Konfiguration, exakt in Xcodes Schreibweise (Werte roh,
# inkl. Anfuehrungszeichen). Einzige Quelle: Aenderungen hier eintragen, dann
# neu generieren; `--check` meldet Drift gegen die eingecheckte project.pbxproj.
APP_BUILD_NUMBER = "3"
APP_DEBUG_SETTINGS = {
    'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
    'CODE_SIGN_ENTITLEMENTS': 'Sources/HengaMac/App.entitlements',
    'CODE_SIGN_IDENTITY': '"Apple Development"',
    'CODE_SIGN_STYLE': 'Automatic',
    'COMBINE_HIDPI_IMAGES': 'YES',
    'CURRENT_PROJECT_VERSION': APP_BUILD_NUMBER,
    'DEAD_CODE_STRIPPING': 'YES',
    'DEVELOPMENT_TEAM': 'G7AU53ARQH',
    'ENABLE_APP_SANDBOX': 'YES',
    'ENABLE_HARDENED_RUNTIME': 'YES',
    'ENABLE_INCOMING_NETWORK_CONNECTIONS': 'NO',
    'ENABLE_OUTGOING_NETWORK_CONNECTIONS': 'NO',
    'ENABLE_RESOURCE_ACCESS_AUDIO_INPUT': 'NO',
    'ENABLE_RESOURCE_ACCESS_BLUETOOTH': 'NO',
    'ENABLE_RESOURCE_ACCESS_CALENDARS': 'NO',
    'ENABLE_RESOURCE_ACCESS_CAMERA': 'NO',
    'ENABLE_RESOURCE_ACCESS_CONTACTS': 'NO',
    'ENABLE_RESOURCE_ACCESS_LOCATION': 'NO',
    'ENABLE_RESOURCE_ACCESS_PRINTING': 'NO',
    'ENABLE_RESOURCE_ACCESS_USB': 'NO',
    'GENERATE_INFOPLIST_FILE': 'NO',
    'INFOPLIST_FILE': 'Sources/HengaMac/Info.plist',
    'INFOPLIST_KEY_CFBundleDisplayName': 'Henga',
    'INFOPLIST_KEY_LSApplicationCategoryType': '"public.app-category.utilities"',
    'LD_RUNPATH_SEARCH_PATHS': ['"$(inherited)"', '"@executable_path/../Frameworks"'],
    'MARKETING_VERSION': '1.0',
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.hehljo.Henga',
    'PRODUCT_NAME': '"$(TARGET_NAME)"',
    'PROVISIONING_PROFILE_SPECIFIER': '""',
    'SWIFT_EMIT_LOC_STRINGS': 'YES',
    'SWIFT_VERSION': '5.0',
}
PROJECT_RELEASE_SETTINGS = {
    'ALWAYS_SEARCH_USER_PATHS': 'NO',
    'CLANG_ANALYZER_NONNULL': 'YES',
    'CLANG_ENABLE_MODULES': 'YES',
    'CLANG_ENABLE_OBJC_ARC': 'YES',
    'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING': 'YES',
    'CLANG_WARN_BOOL_CONVERSION': 'YES',
    'CLANG_WARN_COMMA': 'YES',
    'CLANG_WARN_CONSTANT_CONVERSION': 'YES',
    'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS': 'YES',
    'CLANG_WARN_EMPTY_BODY': 'YES',
    'CLANG_WARN_ENUM_CONVERSION': 'YES',
    'CLANG_WARN_INFINITE_RECURSION': 'YES',
    'CLANG_WARN_INT_CONVERSION': 'YES',
    'CLANG_WARN_NON_LITERAL_NULL_CONVERSION': 'YES',
    'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF': 'YES',
    'CLANG_WARN_OBJC_LITERAL_CONVERSION': 'YES',
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER': 'YES',
    'CLANG_WARN_RANGE_LOOP_ANALYSIS': 'YES',
    'CLANG_WARN_STRICT_PROTOTYPES': 'YES',
    'CLANG_WARN_SUSPICIOUS_MOVE': 'YES',
    'CLANG_WARN_UNREACHABLE_CODE': 'YES',
    'CLANG_WARN__DUPLICATE_METHOD_MATCH': 'YES',
    'COPY_PHASE_STRIP': 'NO',
    'DEAD_CODE_STRIPPING': 'YES',
    'DEBUG_INFORMATION_FORMAT': '"dwarf-with-dsym"',
    'DEVELOPMENT_TEAM': 'G7AU53ARQH',
    'ENABLE_NS_ASSERTIONS': 'NO',
    'ENABLE_STRICT_OBJC_MSGSEND': 'YES',
    'ENABLE_USER_SCRIPT_SANDBOXING': 'YES',
    'GCC_NO_COMMON_BLOCKS': 'YES',
    'GCC_OPTIMIZATION_LEVEL': 's',
    'GCC_WARN_64_TO_32_BIT_CONVERSION': 'YES',
    'GCC_WARN_ABOUT_RETURN_TYPE': 'YES',
    'GCC_WARN_UNDECLARED_SELECTOR': 'YES',
    'GCC_WARN_UNINITIALIZED_AUTOS': 'YES',
    'GCC_WARN_UNUSED_FUNCTION': 'YES',
    'GCC_WARN_UNUSED_VARIABLE': 'YES',
    'MACOSX_DEPLOYMENT_TARGET': '14.0',
    'MTL_ENABLE_DEBUG_INFO': 'NO',
    'SDKROOT': 'macosx',
    'STRING_CATALOG_GENERATE_SYMBOLS': 'YES',
    'SWIFT_COMPILATION_MODE': 'wholemodule',
    'SWIFT_OPTIMIZATION_LEVEL': '"-O"',
}
APP_RELEASE_SETTINGS = {
    'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
    'CODE_SIGN_ENTITLEMENTS': 'Sources/HengaMac/App.entitlements',
    'CODE_SIGN_IDENTITY': '"Apple Development"',
    'CODE_SIGN_STYLE': 'Automatic',
    'COMBINE_HIDPI_IMAGES': 'YES',
    'CURRENT_PROJECT_VERSION': APP_BUILD_NUMBER,
    'DEAD_CODE_STRIPPING': 'YES',
    'DEVELOPMENT_TEAM': 'G7AU53ARQH',
    'ENABLE_APP_SANDBOX': 'YES',
    'ENABLE_HARDENED_RUNTIME': 'YES',
    'ENABLE_INCOMING_NETWORK_CONNECTIONS': 'NO',
    'ENABLE_OUTGOING_NETWORK_CONNECTIONS': 'NO',
    'ENABLE_RESOURCE_ACCESS_AUDIO_INPUT': 'NO',
    'ENABLE_RESOURCE_ACCESS_BLUETOOTH': 'NO',
    'ENABLE_RESOURCE_ACCESS_CALENDARS': 'NO',
    'ENABLE_RESOURCE_ACCESS_CAMERA': 'NO',
    'ENABLE_RESOURCE_ACCESS_CONTACTS': 'NO',
    'ENABLE_RESOURCE_ACCESS_LOCATION': 'NO',
    'ENABLE_RESOURCE_ACCESS_PRINTING': 'NO',
    'ENABLE_RESOURCE_ACCESS_USB': 'NO',
    'GENERATE_INFOPLIST_FILE': 'NO',
    'INFOPLIST_FILE': 'Sources/HengaMac/Info.plist',
    'INFOPLIST_KEY_CFBundleDisplayName': 'Henga',
    'INFOPLIST_KEY_LSApplicationCategoryType': '"public.app-category.utilities"',
    'LD_RUNPATH_SEARCH_PATHS': ['"$(inherited)"', '"@executable_path/../Frameworks"'],
    'MARKETING_VERSION': '1.0',
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.hehljo.Henga',
    'PRODUCT_NAME': '"$(TARGET_NAME)"',
    'PROVISIONING_PROFILE_SPECIFIER': '""',
    'SWIFT_EMIT_LOC_STRINGS': 'YES',
    'SWIFT_VERSION': '5.0',
}
PROJECT_DEBUG_SETTINGS = {
    'ALWAYS_SEARCH_USER_PATHS': 'NO',
    'CLANG_ANALYZER_NONNULL': 'YES',
    'CLANG_ENABLE_MODULES': 'YES',
    'CLANG_ENABLE_OBJC_ARC': 'YES',
    'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING': 'YES',
    'CLANG_WARN_BOOL_CONVERSION': 'YES',
    'CLANG_WARN_COMMA': 'YES',
    'CLANG_WARN_CONSTANT_CONVERSION': 'YES',
    'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS': 'YES',
    'CLANG_WARN_EMPTY_BODY': 'YES',
    'CLANG_WARN_ENUM_CONVERSION': 'YES',
    'CLANG_WARN_INFINITE_RECURSION': 'YES',
    'CLANG_WARN_INT_CONVERSION': 'YES',
    'CLANG_WARN_NON_LITERAL_NULL_CONVERSION': 'YES',
    'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF': 'YES',
    'CLANG_WARN_OBJC_LITERAL_CONVERSION': 'YES',
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER': 'YES',
    'CLANG_WARN_RANGE_LOOP_ANALYSIS': 'YES',
    'CLANG_WARN_STRICT_PROTOTYPES': 'YES',
    'CLANG_WARN_SUSPICIOUS_MOVE': 'YES',
    'CLANG_WARN_UNREACHABLE_CODE': 'YES',
    'CLANG_WARN__DUPLICATE_METHOD_MATCH': 'YES',
    'COPY_PHASE_STRIP': 'NO',
    'DEAD_CODE_STRIPPING': 'YES',
    'DEBUG_INFORMATION_FORMAT': 'dwarf',
    'DEVELOPMENT_TEAM': 'G7AU53ARQH',
    'ENABLE_STRICT_OBJC_MSGSEND': 'YES',
    'ENABLE_TESTABILITY': 'YES',
    'ENABLE_USER_SCRIPT_SANDBOXING': 'YES',
    'GCC_NO_COMMON_BLOCKS': 'YES',
    'GCC_OPTIMIZATION_LEVEL': '0',
    'GCC_WARN_64_TO_32_BIT_CONVERSION': 'YES',
    'GCC_WARN_ABOUT_RETURN_TYPE': 'YES',
    'GCC_WARN_UNDECLARED_SELECTOR': 'YES',
    'GCC_WARN_UNINITIALIZED_AUTOS': 'YES',
    'GCC_WARN_UNUSED_FUNCTION': 'YES',
    'GCC_WARN_UNUSED_VARIABLE': 'YES',
    'MACOSX_DEPLOYMENT_TARGET': '14.0',
    'MTL_ENABLE_DEBUG_INFO': 'INCLUDE_SOURCE',
    'ONLY_ACTIVE_ARCH': 'YES',
    'SDKROOT': 'macosx',
    'STRING_CATALOG_GENERATE_SYMBOLS': 'YES',
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG',
    'SWIFT_OPTIMIZATION_LEVEL': '"-Onone"',
}

def pbx_str(value: str) -> str:
    # Xcodes Schreibweise: nur Zeichen ausserhalb dieser Menge erzwingen Anfuehrungszeichen.
    return value if re.fullmatch(r"[A-Za-z0-9_$/.]+", value) else f'"{value}"'

def normalized(pbxproj: str) -> list:
    # Xcode sortiert Eintraege um und setzt Leerzeilen; verglichen wird der Inhalt.
    return sorted(line.strip() for line in pbxproj.splitlines() if line.strip())

def make_id(key: str) -> str:
    return hashlib.md5(key.encode('utf-8')).hexdigest()[:24].upper()

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    proj_dir = os.path.join(root_dir, "Henga.xcodeproj")
    os.makedirs(proj_dir, exist_ok=True)
    shared_data = os.path.join(proj_dir, "xcshareddata", "xcschemes")
    os.makedirs(shared_data, exist_ok=True)
    
    # Collect source files
    core_files = []
    mac_files = []
    
    for r, _, files in os.walk(os.path.join(root_dir, "Sources", "HengaCore")):
        for f in files:
            if f.endswith(".swift"):
                core_files.append(os.path.relpath(os.path.join(r, f), root_dir))
                
    for r, _, files in os.walk(os.path.join(root_dir, "Sources", "HengaMac")):
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
        "Sources/HengaMac/Assets.xcassets",
        "Sources/HengaMac/Localizable.xcstrings",
        "Sources/HengaMac/Info.plist",
        "Sources/HengaMac/App.entitlements"
    ]
    res_refs = {}
    for rpath in res_files:
        fid = make_id(f"file_ref_{rpath}")
        bid = make_id(f"build_file_{rpath}")
        res_refs[rpath] = (fid, bid)

    TARGET_ID = make_id("target_Henga")
    PROJECT_ID = make_id("project_Henga")
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
    for rpath in ["Sources/HengaMac/Assets.xcassets", "Sources/HengaMac/Localizable.xcstrings"]:
        fid, bid = res_refs[rpath]
        fname = os.path.basename(rpath)
        lines.append(f"\t\t{bid} /* {fname} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fname} */; }};")
    lines.append("/* End PBXBuildFile section */")
    
    # PBXFileReference
    lines.append("/* Begin PBXFileReference section */")
    lines.append(f"\t\t{PRODUCT_REF_ID} /* Henga.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Henga.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for fpath in all_swift_files:
        fid, _ = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {pbx_str(fname)}; path = {pbx_str(fpath)}; sourceTree = SOURCE_ROOT; }};")
    for rpath in res_files:
        fid, _ = res_refs[rpath]
        fname = os.path.basename(rpath)
        if rpath.endswith(".xcassets"):
            ftype = "folder.assetcatalog"
        elif rpath.endswith(".xcstrings"):
            ftype = "text.json.xcstrings"
        else:
            ftype = "text.plist.xml"
        lines.append(f"\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; name = {pbx_str(fname)}; path = {pbx_str(rpath)}; sourceTree = SOURCE_ROOT; }};")
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
    lines.append(f"\t\t\t\t{CORE_GROUP_ID} /* HengaCore */,")
    lines.append(f"\t\t\t\t{MAC_GROUP_ID} /* HengaMac */,")
    lines.append(f"\t\t\t\t{PRODUCTS_GROUP_ID} /* Products */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{CORE_GROUP_ID} /* HengaCore */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for fpath in sorted(core_files):
        fid, _ = file_refs[fpath]
        fname = os.path.basename(fpath)
        lines.append(f"\t\t\t\t{fid} /* {fname} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = HengaCore;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{MAC_GROUP_ID} /* HengaMac */ = {{")
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
    lines.append("\t\t\tname = HengaMac;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{PRODUCTS_GROUP_ID} /* Products */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{PRODUCT_REF_ID} /* Henga.app */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("/* End PBXGroup section */")
    
    # PBXNativeTarget section
    lines.append("/* Begin PBXNativeTarget section */")
    lines.append(f"\t\t{TARGET_ID} /* Henga */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {TARGET_CONFIG_LIST_ID} /* Build configuration list for PBXNativeTarget \"Henga\" */;")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{SOURCES_PHASE_ID} /* Sources */,")
    lines.append(f"\t\t\t\t{FRAMEWORKS_PHASE_ID} /* Frameworks */,")
    lines.append(f"\t\t\t\t{RESOURCES_PHASE_ID} /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdependencies = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Henga;")
    lines.append("\t\t\tproductName = Henga;")
    lines.append(f"\t\t\tproductReference = {PRODUCT_REF_ID} /* Henga.app */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */")
    
    # PBXProject section
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{PROJECT_ID} /* Project object */ = {{")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {")
    lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    lines.append("\t\t\t\tLastUpgradeCheck = 2700;")
    lines.append("\t\t\t\tTargetAttributes = {")
    lines.append(f"\t\t\t\t\t{TARGET_ID} = {{")
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    lines.append("\t\t\t\t\t};")
    lines.append("\t\t\t\t};")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tbuildConfigurationList = {PROJ_CONFIG_LIST_ID} /* Build configuration list for PBXProject \"Henga\" */;")
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
    lines.append(f"\t\t\t\t{TARGET_ID} /* Henga */,")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("/* End PBXProject section */")
    
    # PBXResourcesBuildPhase section
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{RESOURCES_PHASE_ID} /* Resources */ = {{")
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for rpath in ["Sources/HengaMac/Assets.xcassets", "Sources/HengaMac/Localizable.xcstrings"]:
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
    for cid, cname, settings in [
        (PROJ_DEBUG_CONFIG_ID, "Debug", PROJECT_DEBUG_SETTINGS),
        (PROJ_RELEASE_CONFIG_ID, "Release", PROJECT_RELEASE_SETTINGS),
        (TARGET_DEBUG_CONFIG_ID, "Debug", APP_DEBUG_SETTINGS),
        (TARGET_RELEASE_CONFIG_ID, "Release", APP_RELEASE_SETTINGS),
    ]:
        lines.append(f"\t\t{cid} /* {cname} */ = {{")
        lines.append("\t\t\tisa = XCBuildConfiguration;")
        lines.append("\t\t\tbuildSettings = {")
        for key, value in settings.items():
            if isinstance(value, list):
                lines.append(f"\t\t\t\t{key} = (")
                lines.extend(f"\t\t\t\t\t{item}," for item in value)
                lines.append("\t\t\t\t);")
            else:
                lines.append(f"\t\t\t\t{key} = {value};")
        lines.append("\t\t\t};")
        lines.append(f"\t\t\tname = {cname};")
        lines.append("\t\t};")
    lines.append("/* End XCBuildConfiguration section */")
    
    # XCConfigurationList section
    lines.append("/* Begin XCConfigurationList section */")
    lines.append(f"\t\t{PROJ_CONFIG_LIST_ID} /* Build configuration list for PBXProject \"Henga\" */ = {{")
    lines.append("\t\t\tisa = XCConfigurationList;")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{PROJ_DEBUG_CONFIG_ID} /* Debug */,")
    lines.append(f"\t\t\t\t{PROJ_RELEASE_CONFIG_ID} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    
    lines.append(f"\t\t{TARGET_CONFIG_LIST_ID} /* Build configuration list for PBXNativeTarget \"Henga\" */ = {{")
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
    
    target = os.path.join(proj_dir, "project.pbxproj")
    content = "\n".join(lines) + "\n"
    if "--check" in sys.argv:
        # Drift-Gate: Xcode-Aenderungen (Sandbox, Team, Kategorie, Buildnummer)
        # muessen hier eingetragen sein, sonst loescht das naechste Generieren sie.
        with open(target, encoding="utf-8") as f:
            current = f.read()
        if normalized(current) != normalized(content):
            import difflib
            diff = [l for l in difflib.unified_diff(normalized(current), normalized(content), "project.pbxproj", "generator", lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
            print(f"DRIFT: {len(diff)} Zeilen weichen ab (- eingecheckt, + Generator):")
            print("\n".join(diff[:40]))
            sys.exit(1)
        print("OK: project.pbxproj entspricht dem Generator")
        return
    with open(target, "w", encoding="utf-8") as f:
        f.write(content)
        
    print(f"Generated {target}")

if __name__ == "__main__":
    main()

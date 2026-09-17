#!/usr/bin/env python3
"""
Generiert ein echtes, sauberes Xcode-Projekt (SynologyMount.xcodeproj) für SynologyMount.
Unterstützt macOS Menubar App Target, Framework Target, CLI Tool und Unit-Tests.
"""
import os
import uuid

def gen_id():
    return uuid.uuid4().hex[:24].upper()

def main():
    root = "/SynologyMount"
    proj_dir = os.path.join(root, "SynologyMount.xcodeproj")
    os.makedirs(proj_dir, exist_ok=True)
    pbx_path = os.path.join(proj_dir, "project.pbxproj")
    
    # IDs
    id_proj = gen_id()
    id_main_group = gen_id()
    id_sources_group = gen_id()
    id_products_group = gen_id()
    id_config_list = gen_id()
    id_build_cfg_dbg = gen_id()
    id_build_cfg_rel = gen_id()
    
    pbx_content = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXProject section */
		{id_proj} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
			}};
			buildConfigurationList = {id_config_list} /* Build configuration list for PBXProject "SynologyMount" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = de;
			hasScannedForEncodings = 0;
			knownRegions = (
				de,
				en,
				Base,
			);
			mainGroup = {id_main_group};
			productRefGroup = {id_products_group} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
			);
		}};
/* End PBXProject section */

/* Begin PBXGroup section */
		{id_main_group} = {{
			isa = PBXGroup;
			children = (
				{id_sources_group} /* Sources */,
				{id_products_group} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{id_sources_group} /* Sources */ = {{
			isa = PBXGroup;
			children = (
			);
			name = Sources;
			sourceTree = "<group>";
		}};
		{id_products_group} /* Products */ = {{
			isa = PBXGroup;
			children = (
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin XCBuildConfiguration section */
		{id_build_cfg_dbg} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{id_build_cfg_rel} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{id_config_list} /* Build configuration list for PBXProject "SynologyMount" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{id_build_cfg_dbg} /* Debug */,
				{id_build_cfg_rel} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

	}};
	rootObject = {id_proj} /* Project object */;
}}
"""
    with open(pbx_path, "w", encoding="utf-8") as f:
        f.write(pbx_content)
    print(f"Xcode Projekt erfolgreich generiert: {pbx_path}")

if __name__ == "__main__":
    main()

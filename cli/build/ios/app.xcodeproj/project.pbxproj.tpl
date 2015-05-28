<%!
	from uuid import uuid5, NAMESPACE_OID

	class UUID(object):
		def __call__(self, x):
			return str(uuid5(NAMESPACE_OID, x)).replace('-', '')

		def __getattr__(self, name):
			return self(name)

	uuid = UUID()

	filetypes = {
	  '.app': 'wrapper.application',
	  '.framework': 'wrapper.framework',
	  '.nib': 'wrapper.nib',
	  '.xcodeproj': 'wrapper.pb-project',
	  '.bundle': 'wrapper.plug-in',
	  '.xib': 'file.xib',
	  '.a': 'archive.ar',
	  '.c': 'sourcecode.c.c',
	  '.cpp': 'sourcecode.cpp.cpp',
	  '.m': 'sourcecode.c.objc',
	  '.mm': 'sourcecode.cpp.objcpp',
	  '.h': 'sourcecode.c.h',
	  '.s': 'sourcecode.asm',
	  '.plist': 'text.plist.xml',
	  '.strings': 'text.plist.strings',
	  '.json': 'text.json',
	  '.rtf': 'text.rtf',
	  '.txt': 'text',
		'.lua': 'text',
		'.moon': 'text',
	  '.icns': 'image.icns',
	  '.png': 'image.png',
	  '.tiff': 'image.tiff',
	  '.dylib': 'compiled.mach-o.dylib',
  }

	phases = {
		'source': ('.c', '.cpp', '.m', '.mm', '.s'),
		'framework': ('.a', '.framework', '.dylib'),
	}
%>
<%
	def relpath(*p):
		return path.relpath('/'.join(p), build_path).replace('\\', '/')
%>

// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {};
	objectVersion = 46;
	objects = {
		${ uuid.project } = {
			isa = PBXProject;
			buildConfigurationList = ${ uuid.build_configs };
			targets = (${ uuid.target });
		};

		<% build_source_refs = [] %>
		<% build_framework_refs = [] %>
		% for file_dir, _, files in os.walk(path.join(build_path, 'native')):
				% for file in files:
						<%
							file = relpath(file_dir, file);
							file_ref = uuid(file)
							build_ref = uuid(file + 'build')
							ext = path.splitext(file)[1]
						%>
						${ file_ref } = {
							isa = PBXFileReference;
							path = ${ file };
							% if ext in filetypes:
								lastKnownFileType = ${ filetypes[ext] };
							% endif
						};
						% if ext in phases['source']:
							<% build_source_refs.append(build_ref) %>
							${ build_ref } = {isa = PBXBuildFile; fileRef = ${ file_ref };};
						% endif
						% if ext in phases['framework']:
							<% build_framework_refs.append(build_ref) %>
							${ build_ref } = {isa = PBXBuildFile; fileRef = ${ file_ref };};
						% endif
				% endfor
		% endfor

		${ uuid.build_configs } = {
			isa = XCConfigurationList;
			buildConfigurations = (
				${ uuid.build_debug_config },
				${ uuid.build_release_config },
			);
		};
		${ uuid.target } = {
			isa = PBXNativeTarget;
			buildConfigurationList = ${ uuid.target_configs };
			buildPhases = (
				${ uuid.build_source_phase },
				${ uuid.build_framework_phase },
			);
			name = "${ app['name'] }";
			productName = "${ app['name'] }";
			productType = "com.apple.product-type.application";
		};
		${ uuid.build_source_phase } = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				% for build_ref in build_source_refs:
					${ build_ref },
				% endfor
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		${ uuid.build_framework_phase } = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				% for build_ref in build_framework_refs:
					${ build_ref },
				% endfor
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		${ uuid.target_configs } = {
			isa = XCConfigurationList;
			buildConfigurations = (
				${ uuid.target_debug_config },
				${ uuid.target_release_config },
			);
		};

		<%def name="common_build_settings()">
			IPHONEOS_DEPLOYMENT_TARGET = 8.3;
			"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";
			USER_HEADER_SEARCH_PATHS = "$(inherited) \
				${ ' '.join(['native/' + src + '/include' for src in native_modules]) }";
			LIBRARY_SEARCH_PATHS = "$(inherited) \
				${ ' '.join(['native/' + src + '/libs' for src in native_modules]) }";
			SDKROOT = iphoneos;
			ALWAYS_SEARCH_USER_PATHS = NO;
			CLANG_CXX_LANGUAGE_STANDARD = "gnu++0x";
			CLANG_CXX_LIBRARY = "libc++";
			CLANG_ENABLE_MODULES = YES;
			CLANG_ENABLE_OBJC_ARC = YES;
			CLANG_WARN_BOOL_CONVERSION = YES;
			CLANG_WARN_CONSTANT_CONVERSION = YES;
			CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
			CLANG_WARN_EMPTY_BODY = YES;
			CLANG_WARN_ENUM_CONVERSION = YES;
			CLANG_WARN_INT_CONVERSION = YES;
			CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
			CLANG_WARN_UNREACHABLE_CODE = YES;
			CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
			COPY_PHASE_STRIP = NO;
			DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
			ENABLE_STRICT_OBJC_MSGSEND = YES;
			GCC_C_LANGUAGE_STANDARD = gnu99;
			GCC_NO_COMMON_BLOCKS = YES;
			GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
			GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
			GCC_WARN_UNDECLARED_SELECTOR = YES;
			GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
			GCC_WARN_UNUSED_FUNCTION = YES;
			GCC_WARN_UNUSED_VARIABLE = YES;
			TARGETED_DEVICE_FAMILY = "1,2";
		</%def>
		<%def name="common_target_settings()">
			ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			INFOPLIST_FILE = Info.plist;
			LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
			PRODUCT_NAME = "$(TARGET_NAME)";
		</%def>

		${ uuid.build_debug_config } = {
			isa = XCBuildConfiguration;
			name = Debug;
			buildSettings = {
				${ common_build_settings() }
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_SYMBOLS_PRIVATE_EXTERN = NO;
				MTL_ENABLE_DEBUG_INFO = YES;
				ONLY_ACTIVE_ARCH = YES;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
			};
		};
		${ uuid.build_release_config } = {
			isa = XCBuildConfiguration;
			name = Release;
			buildSettings = {
				${ common_build_settings() }
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				VALIDATE_PRODUCT = YES;
			};
		};
		${ uuid.target_debug_config } = {
			isa = XCBuildConfiguration;
			name = Debug;
			buildSettings = {
				${ common_target_settings() }
			};
		};
		${ uuid.target_release_config } = {
			isa = XCBuildConfiguration;
			name = Release;
			buildSettings = {
				${ common_target_settings() }
			};
		};
	};

	rootObject = ${ uuid.project };
}

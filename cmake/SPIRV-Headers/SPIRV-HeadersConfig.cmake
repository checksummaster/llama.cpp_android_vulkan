get_filename_component(_SPIRV_HEADERS_INCLUDE_DIR
  "${CMAKE_CURRENT_LIST_DIR}/../../android-ndk-r27d/sources/third_party/shaderc/third_party/spirv-tools/external/spirv-headers/include"
  ABSOLUTE
)

if (NOT EXISTS "${_SPIRV_HEADERS_INCLUDE_DIR}/spirv/unified1/spirv.hpp")
  message(FATAL_ERROR "SPIRV-Headers include dir not found: ${_SPIRV_HEADERS_INCLUDE_DIR}")
endif()

add_library(SPIRV-Headers::SPIRV-Headers INTERFACE IMPORTED)
set_target_properties(SPIRV-Headers::SPIRV-Headers PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "${_SPIRV_HEADERS_INCLUDE_DIR}"
)

set(SPIRV-Headers_FOUND TRUE)
set(SPIRV-Headers_INCLUDE_DIR "${_SPIRV_HEADERS_INCLUDE_DIR}")
set(SPIRV-Headers_INCLUDE_DIRS "${_SPIRV_HEADERS_INCLUDE_DIR}")

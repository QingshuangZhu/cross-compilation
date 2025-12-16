# aarch64_be-toolchain.cmake
# specified target system and architecture
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# specified cross-compiler prefix
set(tools /opt/toolchain/gcc-arm-10.2-2020.11-x86_64-aarch64_be-none-linux-gnu/bin)
set(CMAKE_C_COMPILER   ${tools}/aarch64_be-none-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${tools}/aarch64_be-none-linux-gnu-c++)

# specified target system root path
set(CMAKE_SYSROOT /opt/toolchain/gcc-arm-10.2-2020.11-x86_64-aarch64_be-none-linux-gnu/aarch64_be-none-linux-gnu/libc)
# specified root path for searching libraries and headers (adjust according to your installation path)
set(CMAKE_FIND_ROOT_PATH /opt/toolchain/gcc-arm-10.2-2020.11-x86_64-aarch64_be-none-linux-gnu/aarch64_be-none-linux-gnu)

# tell CMake to search for cross dependencies in these paths, not the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

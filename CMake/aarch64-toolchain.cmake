# aarch64-toolchain.cmake
# specified target system and architecture
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# specified cross-compiler prefix
set(tools /opt/toolchain/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu/bin)
set(CMAKE_C_COMPILER   ${tools}/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${tools}/aarch64-linux-gnu-g++)

# specified root path for searching libraries and headers (adjust according to your installation path)
set(CMAKE_FIND_ROOT_PATH /opt/toolchain/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu/aarch64-linux-gnu)

# tell CMake to search for cross dependencies in these paths, not the host environment
set(CMAKE_SYSROOT /opt/toolchain/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu/aarch64-linux-gnu/libc)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

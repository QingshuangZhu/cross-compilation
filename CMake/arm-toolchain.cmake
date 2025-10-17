# arm-toolchain.cmake
# specified target system and architecture
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

# specified cross-compiler prefix
set(tools /opt/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin)
set(CMAKE_C_COMPILER   ${tools}/arm-none-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER ${tools}/arm-none-linux-gnueabihf-g++)

# specified target system root path
set(CMAKE_SYSROOT /opt/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/arm-none-linux-gnueabihf/libc)
# specified root path for searching libraries and headers (adjust according to your installation path)
set(CMAKE_FIND_ROOT_PATH /opt/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/arm-none-linux-gnueabihf)

# tell CMake to search for cross dependencies in these paths, not the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

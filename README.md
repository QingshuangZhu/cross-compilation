# Cross Compilation
Autotools and CMake are both build system generators, which can configure the toolchain and generate build scripts (such as Makefile) for actual compilation based on the project's source code and system environment. 

### Toolchain
* Download the Arm GUN Toolchain from [here](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads) and extract it to `/opt/toolchain` directory. 
* Download the NDK from [here](https://developer.android.com/ndk/downloads) and extract it to `/opt/android-ndk-r26d` directory.
* Download the RISC-V GNU Compiler Toolchain from [here](https://github.com/riscv-collab/riscv-gnu-toolchain/releases).
* Download the LLVM Toolchain from [here](https://github.com/llvm/llvm-project/releases).

### [Autotools](https://www.gnu.org/software/automake/manual/html_node/Autotools-Introduction.html)
Autotools is a set of tools used to generate build scripts, including `autoconf`, `automake`, `libtool` and `aclocal`. The general process is as follows:
1. Write the `configure.ac` file, which is used to generate the `configure` script.
2. Run `autoconf` to generate the `configure` script.
3. Write the `Makefile.am` file, which is used to generate the `Makefile.in` file.
4. Run `automake` to generate the `Makefile.in` file.
5. Run `./configure` to generate the `Makefile` file.
6. Run `make` to compile the project.

Autotools cross-compilation requires explicitly specifying the toolchain and defining the build/host/target triple. `--build`: specify the build system, `--host`: specify the runtime platform, `--target`: used only when building the toolchain itself, specifying the platform for which the toolchain will generate code. Run `./configure --build=xxx --host=xxx --target=xxx --prefix=xxx` to generate the build scripts. then `make` to compile the project. Cross compilation [Lighttpd](https://github.com/lighttpd/lighttpd1.4) example: `cd Autotools && ./build_lighttpd_linux.sh`

### [CMake](https://cmake.org/)
CMake is a cross-platform build system generator, which can generate build scripts for various platforms, including Windows, Linux, macOS, etc. The general process is as follows:
1. Write the `CMakeLists.txt` file, which is used to generate the build scripts.
2. Run `cmake` to generate the build scripts.
3. Run `make` to compile the project.

CMake adopts a more modern and clearer approach: the [Toolchain File](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html). This is a `.cmake` file written by the user that explicitly tells CMake all the information about the target platform. This method completely separates the configuration of "compiling for which platform" from the logic of "how the project is built" (CMakeLists.txt). Cross compilation [protobuf](https://github.com/protocolbuffers/protobuf) example: `cd CMake && ./build_protobuf_linux.sh`

#!/usr/bin/env python3
"""Patch nginx's auto/* configure scripts for cross-compilation support.

nginx's auto/* scripts compile test programs and run them to detect system
characteristics. For cross-compilation, ARM binaries can't run on x86 hosts.
This script patches the key files to skip execution and use hardcoded values
for aarch64-android.
"""
import os
import sys

if len(sys.argv) < 2:
    print("Usage: patch_nginx_cross.py <nginx-source-dir>")
    sys.exit(1)

bd = sys.argv[1]

# 1) auto/feature: skip running test binary if it's for a different arch
with open(os.path.join(bd, "auto/feature"), "r") as f:
    content = f.read()

patch_text = """
# Cross-compile: skip execution if binary is for different arch
if [ "$ngx_feature_run" = "yes" ] || [ "$ngx_feature_run" = "value" ]; then
    if [ -x "$NGX_AUTOTEST" ] && file "$NGX_AUTOTEST" 2>/dev/null | grep -qE 'ARM|aarch64'; then
        ngx_feature_run=none
    fi
fi
"""

# The eval line in auto/feature has literal backslash-quote sequences
target = 'eval "/bin/sh -c \\"$ngx_test\\" >> $NGX_AUTOCONF_ERR 2>&1"'
if target in content:
    content = content.replace(target, target + patch_text)
    with open(os.path.join(bd, "auto/feature"), "w") as f:
        f.write(content)
    print("Patched auto/feature")
else:
    print("WARNING: Could not find target in auto/feature")

# 2) auto/types/sizeof: return hardcoded 8 for aarch64
with open(os.path.join(bd, "auto/types/sizeof"), "r") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "ngx_size=`$NGX_AUTOTEST`" in line:
        indent = line[: len(line) - len(line.lstrip())]
        new_lines.append(
            indent
            + "if [ -x \"$NGX_AUTOTEST\" ] && file \"$NGX_AUTOTEST\" 2>/dev/null | grep -qE 'ARM|aarch64'; then\n"
        )
        new_lines.append(indent + "    ngx_size=8\n")
        new_lines.append(indent + "else\n")
        new_lines.append(indent + "    ngx_size=`$NGX_AUTOTEST`\n")
        new_lines.append(indent + "fi\n")
    else:
        new_lines.append(line)

with open(os.path.join(bd, "auto/types/sizeof"), "w") as f:
    f.writelines(new_lines)
print("Patched auto/types/sizeof")

# 3) auto/endianness: assume little-endian (correct for aarch64)
with open(os.path.join(bd, "auto/endianness"), "r") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "if $NGX_AUTOTEST >/dev/null 2>&1; then" in line and "elif" not in line:
        indent = line[: len(line) - len(line.lstrip())]
        new_lines.append(
            indent
            + "if [ -x \"$NGX_AUTOTEST\" ] && file \"$NGX_AUTOTEST\" 2>/dev/null | grep -qE 'ARM|aarch64'; then\n"
        )
        new_lines.append(
            indent + "    :  # cross-compile: assume little endian (correct for aarch64)\n"
        )
        new_lines.append(indent + "elif $NGX_AUTOTEST >/dev/null 2>&1; then\n")
    else:
        new_lines.append(line)

with open(os.path.join(bd, "auto/endianness"), "w") as f:
    f.writelines(new_lines)
print("Patched auto/endianness")

# 4) auto/cc/sunc: skip sun compiler detection (not applicable for Android)
with open(os.path.join(bd, "auto/cc/sunc"), "r") as f:
    content = f.read()
content = content.replace("ngx_sunc_ver=`$NGX_AUTOTEST`", "ngx_sunc_ver=unknown")
with open(os.path.join(bd, "auto/cc/sunc"), "w") as f:
    f.write(content)
print("Patched auto/cc/sunc")

# 5) src/event/ngx_event.h: replace EPOLLIN/EPOLLOUT macros with literals
#    to avoid __poll_t cast issues in preprocessor expressions on Android NDK
with open(os.path.join(bd, "src/event/ngx_event.h"), "r") as f:
    content = f.read()
content = content.replace(
    "#define NGX_READ_EVENT     (EPOLLIN|EPOLLRDHUP)",
    "#define NGX_READ_EVENT     0x00002001"
)
content = content.replace(
    "#define NGX_WRITE_EVENT    EPOLLOUT",
    "#define NGX_WRITE_EVENT    0x00000004"
)
with open(os.path.join(bd, "src/event/ngx_event.h"), "w") as f:
    f.write(content)
print("Patched src/event/ngx_event.h")

# 6) src/event/modules/ngx_epoll_module.c: replace EPOLLIN/EPOLLOUT in #if
#    expressions with literal values (same __poll_t issue as above)
with open(os.path.join(bd, "src/event/modules/ngx_epoll_module.c"), "r") as f:
    content = f.read()
content = content.replace(
    "#if (NGX_READ_EVENT != EPOLLIN|EPOLLRDHUP)",
    "#if (NGX_READ_EVENT != 0x00002001)"
)
content = content.replace(
    "#if (NGX_WRITE_EVENT != EPOLLOUT)",
    "#if (NGX_WRITE_EVENT != 0x00000004)"
)
with open(os.path.join(bd, "src/event/modules/ngx_epoll_module.c"), "w") as f:
    f.write(content)
print("Patched src/event/modules/ngx_epoll_module.c")

#!/usr/bin/env python3
"""
Patch RoutingConnection.m to inject IPC auth guard.
Injects after 'path = [url path]' so we get the real request path.
If auth fails, changes path to /__blocked__ → WDA returns 'unknown command'.
"""
import sys
import os

def find_routing_connection(wda_dir):
    for root, dirs, files in os.walk(wda_dir):
        for f in files:
            if f == "RoutingConnection.m":
                return os.path.join(root, f)
    return None

def patch_file(filepath, auth_key, route_prefix):
    with open(filepath, 'r') as f:
        content = f.read()

    target = 'path = [url path];'
    if target not in content:
        print(f"ERROR: Could not find '{target}' in {filepath}")
        sys.exit(1)

    # Inject auth check right after path = [url path];
    # If auth fails → change path to /__blocked__ → WDA returns error
    # No extra imports needed, no custom classes
    replacement = target + '''

    // ═══ IPC Auth Guard ═══
    {
      BOOL _ipcIsStatus = [path isEqualToString:@"/status"] || [path hasPrefix:@"/status?"];
      if (!_ipcIsStatus) {
        NSString *_ipcPrefix = @"/''' + route_prefix + '''/";
        if ([path hasPrefix:_ipcPrefix]) {
          NSString *_ipcAuth = [request headerField:@"X-IPC-Auth"];
          if ([@"''' + auth_key + '''" isEqualToString:_ipcAuth]) {
            path = [path substringFromIndex:_ipcPrefix.length - 1];
          } else {
            path = @"/__ipc_blocked__";
          }
        } else {
          path = @"/__ipc_blocked__";
        }
      }
    }
    // ═══ End IPC Auth Guard ═══'''

    content = content.replace(target, replacement, 1)

    with open(filepath, 'w') as f:
        f.write(content)

    print(f"OK: Patched {filepath}")
    print(f"  Auth key: {auth_key[:8]}...")
    print(f"  Route prefix: {route_prefix}")

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <wda_dir> <auth_key> <route_prefix>")
        sys.exit(1)

    wda_dir = sys.argv[1]
    auth_key = sys.argv[2]
    route_prefix = sys.argv[3]

    rc_file = find_routing_connection(wda_dir)
    if not rc_file:
        print(f"ERROR: RoutingConnection.m not found in {wda_dir}")
        sys.exit(1)

    print(f"Found: {rc_file}")
    patch_file(rc_file, auth_key, route_prefix)

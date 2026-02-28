#!/usr/bin/env python3
"""
Patch RoutingConnection.m to inject IPC auth guard directly into
httpResponseForMethod:URI: — after path = [url path] so we get the real path.
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
        lines = f.readlines()

    # Find the line: path = [url path];
    inject_after = -1
    for i, line in enumerate(lines):
        if 'path = [url path]' in line:
            inject_after = i
            break

    if inject_after == -1:
        print(f"ERROR: Could not find 'path = [url path]' in {filepath}")
        sys.exit(1)

    auth_code = f'''
  // ═══ IPC Auth Guard (injected at build time) ═══
  {{
    static NSString *_ipcKey = @"{auth_key}";
    static NSString *_ipcPrefix = @"/{route_prefix}/";
    BOOL _isStatus = [path isEqualToString:@"/status"] || [path hasPrefix:@"/status?"];
    if (!_isStatus) {{
      BOOL _hasPrefix = [path hasPrefix:_ipcPrefix];
      NSString *_authVal = [request headerField:@"X-IPC-Auth"];
      BOOL _hasAuth = [_ipcKey isEqualToString:_authVal];
      if (_hasPrefix && _hasAuth) {{
        path = [path substringFromIndex:_ipcPrefix.length - 1];
      }} else {{
        NSData *_body = [@"{{\\"value\\":{{\\"error\\":\\"unauthorized\\",\\"message\\":\\"Forbidden\\"}}}}"
                         dataUsingEncoding:NSUTF8StringEncoding];
        return [[HTTPDataResponse alloc] initWithData:_body];
      }}
    }}
  }}
  // ═══ End IPC Auth Guard ═══
'''

    # Insert after "path = [url path];" line
    lines.insert(inject_after + 1, auth_code)

    with open(filepath, 'w') as f:
        f.writelines(lines)

    print(f"OK: Patched {filepath}")
    print(f"  Injected after line {inject_after + 1}")
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

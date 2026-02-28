// IPCAuthGuard.m — iPhone Control WDA Auth Guard
//
// Dylib tự động hook vào WDA HTTP server qua +load.
// Swizzle RoutingConnection.httpResponseForMethod:URI:
// để kiểm tra header X-IPC-Auth trên MỌI request.
//
// Request không có auth header hoặc sai key → bị reject (HTTP 403).
// __IPC_AUTH_KEY__ được thay thế bằng key thật lúc build.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ═══════════════════════════════════════════════════════
// Auth key — placeholder replaced at build time
// ═══════════════════════════════════════════════════════
static NSString *const kIPCAuthKey    = @"__IPC_AUTH_KEY__";
static NSString *const kIPCAuthHeader = @"X-IPC-Auth";

// Store original IMP
static IMP _orig_httpResponse = NULL;

// ═══════════════════════════════════════════════════════
// Runtime 403 response class
// ═══════════════════════════════════════════════════════
static Class _forbiddenResponseClass = Nil;

static void createForbiddenResponseClass(void) {
    Class superCls = NSClassFromString(@"HTTPDataResponse");
    if (!superCls) return;

    _forbiddenResponseClass = objc_allocateClassPair(superCls, "IPCForbiddenResponse", 0);
    if (!_forbiddenResponseClass) {
        // Already exists (shouldn't happen)
        _forbiddenResponseClass = NSClassFromString(@"IPCForbiddenResponse");
        return;
    }

    // Override -(NSInteger)status to return 403
    SEL statusSel = @selector(status);
    IMP statusImp = imp_implementationWithBlock(^NSInteger(id self) {
        return 403;
    });
    class_addMethod(_forbiddenResponseClass, statusSel, statusImp, "q@:");

    objc_registerClassPair(_forbiddenResponseClass);
}

static id createForbiddenResponse(void) {
    if (!_forbiddenResponseClass) return nil;

    NSData *body = [@"{\"value\":{\"error\":\"unauthorized\",\"message\":\"X-IPC-Auth header missing or invalid\"}}"
                    dataUsingEncoding:NSUTF8StringEncoding];

    id resp = ((id(*)(id, SEL))objc_msgSend)(
        _forbiddenResponseClass, @selector(alloc)
    );
    resp = ((id(*)(id, SEL, id))objc_msgSend)(
        resp, NSSelectorFromString(@"initWithData:"), body
    );
    return resp;
}

// ═══════════════════════════════════════════════════════
// Swizzled HTTP handler — checks auth on every request
// ═══════════════════════════════════════════════════════
static id ipc_httpResponseForMethod(id self, SEL _cmd, NSString *method, NSString *path) {
    // Allow /status without auth (basic health check, no sensitive data)
    if ([path isEqualToString:@"/status"] || [path hasPrefix:@"/status?"]) {
        return ((id(*)(id, SEL, id, id))_orig_httpResponse)(self, _cmd, method, path);
    }

    // Get HTTP request object from the connection
    id request = ((id(*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(@"request"));

    if (request) {
        NSString *authValue = ((id(*)(id, SEL, id))objc_msgSend)(
            request, NSSelectorFromString(@"headerField:"), kIPCAuthHeader
        );

        if ([kIPCAuthKey isEqualToString:authValue]) {
            // Auth OK — pass to original handler
            return ((id(*)(id, SEL, id, id))_orig_httpResponse)(self, _cmd, method, path);
        }

        NSLog(@"[IPC-Auth] REJECTED: %@ %@ (got: %@)", method, path, authValue ?: @"<none>");
        return createForbiddenResponse();
    }

    // No request object (shouldn't happen) — reject
    return createForbiddenResponse();
}

// ═══════════════════════════════════════════════════════
// IPCAuthGuard — auto-installs via +load
// ═══════════════════════════════════════════════════════
@interface IPCAuthGuard : NSObject
@end

@implementation IPCAuthGuard

+ (void)load {
    // Skip if placeholder not replaced (dev/test)
    if ([kIPCAuthKey isEqualToString:@"__IPC_AUTH_KEY__"]) {
        NSLog(@"[IPC-Auth] WARNING: Auth key is placeholder, auth DISABLED");
        return;
    }

    // Create the 403 response class at runtime
    createForbiddenResponseClass();

    // Install hook — RoutingConnection should be loaded by now
    // (it's in WebDriverAgentLib.framework which loads before main binary's +load)
    Class routingConn = NSClassFromString(@"RoutingConnection");

    if (routingConn) {
        [self installHookOnClass:routingConn];
    } else {
        // Fallback: try after a short delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            Class rc = NSClassFromString(@"RoutingConnection");
            if (rc) {
                [self installHookOnClass:rc];
            } else {
                NSLog(@"[IPC-Auth] ERROR: RoutingConnection not found — auth NOT active!");
            }
        });
    }
}

+ (void)installHookOnClass:(Class)cls {
    SEL sel = @selector(httpResponseForMethod:URI:);
    Method m = class_getInstanceMethod(cls, sel);

    if (!m) {
        NSLog(@"[IPC-Auth] ERROR: httpResponseForMethod:URI: not found on %@", cls);
        return;
    }

    _orig_httpResponse = method_setImplementation(m, (IMP)ipc_httpResponseForMethod);
    NSLog(@"[IPC-Auth] Auth guard ACTIVE (key: %.8s...)", kIPCAuthKey.UTF8String);
}

@end

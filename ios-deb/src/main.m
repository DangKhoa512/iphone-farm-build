#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HTTPServer.h"
#import "ScreenCapture.h"

// ---------------------------------------------------------------------------
// Minimal UIApplication delegate — keeps the run loop alive so UIKit works
// ---------------------------------------------------------------------------
@interface FarmAppDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation FarmAppDelegate
- (BOOL)application:(UIApplication *)app
    didFinishLaunchingWithOptions:(NSDictionary *)opts {

    // Invisible window to satisfy UIKit internals
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _window.backgroundColor = [UIColor clearColor];
    _window.windowLevel     = -CGFLOAT_MAX;
    [_window makeKeyAndVisible];
    return YES;
}
@end

// ---------------------------------------------------------------------------

static void parseArgs(int argc, char *argv[],
                      uint16_t *port, NSInteger *fps, NSInteger *quality)
{
    *port    = 7777;
    *fps     = 15;
    *quality = 75;
    for (int i = 1; i < argc - 1; i++) {
        if (strcmp(argv[i], "--port")    == 0) *port    = (uint16_t)atoi(argv[i+1]);
        if (strcmp(argv[i], "--fps")     == 0) *fps     = atoi(argv[i+1]);
        if (strcmp(argv[i], "--quality") == 0) *quality = atoi(argv[i+1]);
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        uint16_t port; NSInteger fps, quality;
        parseArgs(argc, argv, &port, &fps, &quality);

        NSLog(@"[farm-server] Starting  port=%d  fps=%ld  quality=%ld",
              port, (long)fps, (long)quality);

        [ScreenCapture shared].quality = quality;
        [ScreenCapture shared].scale   = 1.0;

        // Start HTTP server before UIApplication so port is open ASAP
        if (![[HTTPServer shared] startWithPort:port fps:fps]) {
            NSLog(@"[farm-server] ERROR: could not bind port %d", port);
            return 1;
        }

        // Run UIApplication so UIKit can render views
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([FarmAppDelegate class]));
    }
}

#import "ScreenCapture.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

@implementation ScreenCapture

+ (instancetype)shared {
    static ScreenCapture *instance;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ instance = [self new]; });
    return instance;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _quality = 75;
    _scale   = 1.0;
    return self;
}

- (NSData *)captureJPEG {
    __block UIImage *image = nil;

    // Must run on main thread to access UIKit layer tree
    if ([NSThread isMainThread]) {
        image = [self _renderScreen];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            image = [self _renderScreen];
        });
    }

    if (!image) return nil;
    return [self _encodeJPEG:image quality:self.quality];
}

// ---------------------------------------------------------------------------

- (UIImage *)_renderScreen {
    UIScreen *screen = [UIScreen mainScreen];
    CGRect    bounds = screen.bounds;
    CGFloat   scale  = screen.scale * self.scale;

    // Collect all windows sorted by window level
    NSArray<UIWindow *> *windows = [UIApplication sharedApplication].windows;

    UIGraphicsBeginImageContextWithOptions(bounds.size, YES, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) { UIGraphicsEndImageContext(); return nil; }

    // Fill black background
    [[UIColor blackColor] setFill];
    UIRectFill(bounds);

    for (UIWindow *win in windows) {
        if (!win.hidden && win.alpha > 0.0) {
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, win.frame.origin.x, win.frame.origin.y);
            [win drawViewHierarchyInRect:win.bounds afterScreenUpdates:NO];
            CGContextRestoreGState(ctx);
        }
    }

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (NSData *)_encodeJPEG:(UIImage *)image quality:(NSInteger)quality {
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData(
        (__bridge CFMutableDataRef)data,
        kUTTypeJPEG,
        1, NULL);
    if (!dest) return UIImageJPEGRepresentation(image, quality / 100.0);

    NSDictionary *props = @{
        (__bridge id)kCGImageDestinationLossyCompressionQuality : @(quality / 100.0)
    };
    CGImageDestinationAddImage(dest, image.CGImage, (__bridge CFDictionaryRef)props);
    CGImageDestinationFinalize(dest);
    CFRelease(dest);
    return data;
}

@end

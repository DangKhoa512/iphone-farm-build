#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ScreenCapture : NSObject

@property (nonatomic, assign) NSInteger quality;   // JPEG quality 1-100
@property (nonatomic, assign) CGFloat    scale;    // render scale (0.5 = half)

+ (instancetype)shared;
- (NSData *)captureJPEG;

@end

#pragma once
#import <Foundation/Foundation.h>

@interface HTTPServer : NSObject

@property (nonatomic, assign) uint16_t  port;
@property (nonatomic, assign) NSInteger fps;

+ (instancetype)shared;
- (BOOL)startWithPort:(uint16_t)port fps:(NSInteger)fps;
- (void)stop;

@end

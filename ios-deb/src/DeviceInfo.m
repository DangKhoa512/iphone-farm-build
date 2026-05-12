#import "DeviceInfo.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

@implementation DeviceInfo

+ (NSDictionary *)currentInfo {
    struct utsname sysInfo;
    uname(&sysInfo);

    UIDevice *dev    = [UIDevice currentDevice];
    UIScreen *screen = [UIScreen mainScreen];

    return @{
        @"udid"         : [self _udid],
        @"name"         : dev.name ?: @"",
        @"model"        : dev.model ?: @"",
        @"hw_model"     : @(sysInfo.machine),
        @"ios_version"  : dev.systemVersion ?: @"",
        @"screen_w"     : @((NSInteger)(screen.bounds.size.width * screen.scale)),
        @"screen_h"     : @((NSInteger)(screen.bounds.size.height * screen.scale)),
        @"screen_scale" : @(screen.scale),
        @"wifi_ip"      : [self _wifiIP] ?: @"",
        @"server_port"  : @7777,
    };
}

+ (NSString *)_udid {
    // On jailbroken devices we can read the real UDID from lockdownd cache
    NSString *path = @"/var/root/Library/Lockdown/uuid.plist";
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    if (d[@"DeviceUDID"]) return d[@"DeviceUDID"];
    return [UIDevice currentDevice].identifierForVendor.UUIDString ?: @"unknown";
}

+ (NSString *)_wifiIP {
    struct ifaddrs *interfaces = NULL;
    getifaddrs(&interfaces);
    NSString *result = nil;
    for (struct ifaddrs *i = interfaces; i; i = i->ifa_next) {
        if (i->ifa_addr->sa_family == AF_INET &&
            strcmp(i->ifa_name, "en0") == 0) {
            char buf[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &((struct sockaddr_in *)i->ifa_addr)->sin_addr,
                      buf, sizeof(buf));
            result = @(buf);
            break;
        }
    }
    freeifaddrs(interfaces);
    return result;
}

@end

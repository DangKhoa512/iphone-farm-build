#import "HTTPServer.h"
#import "ScreenCapture.h"
#import "DeviceInfo.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>

#define MJPEG_BOUNDARY  "--farmframe"
#define HTTP_404        "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
#define HTTP_200_JSON   "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n"

// ---------------------------------------------------------------------------
// Per-client state
// ---------------------------------------------------------------------------
@interface FarmClient : NSObject
@property (nonatomic, assign) int  fd;
@property (nonatomic, assign) BOOL streaming;
@end
@implementation FarmClient
@end

// ---------------------------------------------------------------------------

@interface HTTPServer ()
@property (nonatomic, assign) int       listenFd;
@property (nonatomic, strong) NSMutableArray<FarmClient *> *clients;
@property (nonatomic, strong) dispatch_queue_t  acceptQueue;
@property (nonatomic, strong) dispatch_queue_t  captureQueue;
@property (nonatomic, strong) dispatch_source_t captureTimer;
@property (nonatomic, assign) BOOL running;
@end

@implementation HTTPServer

+ (instancetype)shared {
    static HTTPServer *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [self new]; });
    return s;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _clients      = [NSMutableArray new];
    _acceptQueue  = dispatch_queue_create("farm.accept",  DISPATCH_QUEUE_SERIAL);
    _captureQueue = dispatch_queue_create("farm.capture", DISPATCH_QUEUE_SERIAL);
    return self;
}

// ---------------------------------------------------------------------------
#pragma mark Start / Stop
// ---------------------------------------------------------------------------

- (BOOL)startWithPort:(uint16_t)port fps:(NSInteger)fps {
    _port = port;
    _fps  = fps;

    _listenFd = socket(AF_INET, SOCK_STREAM, 0);
    if (_listenFd < 0) { perror("socket"); return NO; }

    int yes = 1;
    setsockopt(_listenFd, SOL_SOCKET,  SO_REUSEADDR, &yes, sizeof(yes));
    setsockopt(_listenFd, IPPROTO_TCP, TCP_NODELAY,  &yes, sizeof(yes));

    struct sockaddr_in addr = {0};
    addr.sin_family      = AF_INET;
    addr.sin_port        = htons(port);
    addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(_listenFd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind"); close(_listenFd); return NO;
    }
    listen(_listenFd, 32);
    _running = YES;

    NSLog(@"[farm-server] Listening on port %d  fps=%ld", port, (long)fps);
    [self _startAcceptLoop];
    [self _startCaptureTimer];
    return YES;
}

- (void)stop {
    _running = NO;
    close(_listenFd);
    @synchronized(_clients) {
        for (FarmClient *c in _clients) close(c.fd);
        [_clients removeAllObjects];
    }
}

// ---------------------------------------------------------------------------
#pragma mark Accept Loop
// ---------------------------------------------------------------------------

- (void)_startAcceptLoop {
    dispatch_async(_acceptQueue, ^{
        while (self.running) {
            struct sockaddr_in caddr = {0};
            socklen_t clen = sizeof(caddr);
            int cfd = accept(self.listenFd, (struct sockaddr *)&caddr, &clen);
            if (cfd < 0) { if (self.running) perror("accept"); break; }

            int flag = 1;
            setsockopt(cfd, IPPROTO_TCP, TCP_NODELAY, &flag, sizeof(flag));

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                [self _handleClient:cfd];
            });
        }
    });
}

// ---------------------------------------------------------------------------
#pragma mark Request Handling
// ---------------------------------------------------------------------------

- (void)_handleClient:(int)cfd {
    // Read request line
    char buf[2048] = {0};
    ssize_t n = recv(cfd, buf, sizeof(buf) - 1, 0);
    if (n <= 0) { close(cfd); return; }

    NSString *req = [NSString stringWithUTF8String:buf];
    NSString *path = [self _parsePath:req];

    if ([path isEqualToString:@"/stream"]) {
        [self _serveStream:cfd];
    } else if ([path isEqualToString:@"/screenshot"]) {
        [self _serveScreenshot:cfd];
    } else if ([path isEqualToString:@"/info"]) {
        [self _serveInfo:cfd];
    } else {
        send(cfd, HTTP_404, strlen(HTTP_404), 0);
        close(cfd);
    }
}

- (NSString *)_parsePath:(NSString *)request {
    NSArray *lines = [request componentsSeparatedByString:@"\r\n"];
    if (!lines.count) return @"/";
    NSArray *parts = [lines[0] componentsSeparatedByString:@" "];
    if (parts.count < 2) return @"/";
    NSString *rawPath = parts[1];
    NSRange q = [rawPath rangeOfString:@"?"];
    return (q.location != NSNotFound) ? [rawPath substringToIndex:q.location] : rawPath;
}

// ---------------------------------------------------------------------------
#pragma mark /stream  — MJPEG
// ---------------------------------------------------------------------------

- (void)_serveStream:(int)cfd {
    // HTTP header
    const char *header =
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: multipart/x-mixed-replace; boundary=" MJPEG_BOUNDARY "\r\n"
        "Cache-Control: no-cache\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Connection: keep-alive\r\n\r\n";
    if (send(cfd, header, strlen(header), 0) < 0) { close(cfd); return; }

    FarmClient *client = [FarmClient new];
    client.fd        = cfd;
    client.streaming = YES;
    @synchronized(self.clients) { [self.clients addObject:client]; }

    // Block until client disconnects; frame push handled by capture timer
    while (client.streaming) {
        // Probe: send zero-byte; detect disconnect
        char probe;
        ssize_t r = recv(cfd, &probe, 1, MSG_DONTWAIT);
        if (r == 0 || (r < 0 && errno != EAGAIN && errno != EWOULDBLOCK)) break;
        [NSThread sleepForTimeInterval:0.5];
    }

    client.streaming = NO;
    @synchronized(self.clients) { [self.clients removeObject:client]; }
    close(cfd);
}

// ---------------------------------------------------------------------------
#pragma mark Capture Timer  — pushes JPEG to all MJPEG clients
// ---------------------------------------------------------------------------

- (void)_startCaptureTimer {
    double interval = 1.0 / MAX(1, self.fps);
    _captureTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                           0, 0, _captureQueue);
    dispatch_source_set_timer(_captureTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              (uint64_t)(interval * NSEC_PER_SEC),
                              (uint64_t)(0.005 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(_captureTimer, ^{
        [self _pushFrame];
    });
    dispatch_resume(_captureTimer);
}

- (void)_pushFrame {
    NSArray<FarmClient *> *snapshot;
    @synchronized(self.clients) { snapshot = [self.clients copy]; }
    if (!snapshot.count) return;

    NSData *jpeg = [[ScreenCapture shared] captureJPEG];
    if (!jpeg) return;

    NSString *partHeader = [NSString stringWithFormat:
        @"\r\n" MJPEG_BOUNDARY "\r\n"
        "Content-Type: image/jpeg\r\n"
        "Content-Length: %lu\r\n\r\n",
        (unsigned long)jpeg.length];
    const char *hdrBytes = partHeader.UTF8String;
    size_t       hdrLen  = strlen(hdrBytes);

    NSMutableArray *dead = [NSMutableArray new];
    for (FarmClient *c in snapshot) {
        if (!c.streaming) continue;
        if (send(c.fd, hdrBytes,   hdrLen,       MSG_NOSIGNAL) < 0 ||
            send(c.fd, jpeg.bytes, jpeg.length,  MSG_NOSIGNAL) < 0) {
            c.streaming = NO;
            [dead addObject:c];
        }
    }
    if (dead.count) {
        @synchronized(self.clients) { [self.clients removeObjectsInArray:dead]; }
    }
}

// ---------------------------------------------------------------------------
#pragma mark /screenshot  — single JPEG
// ---------------------------------------------------------------------------

- (void)_serveScreenshot:(int)cfd {
    NSData *jpeg = [[ScreenCapture shared] captureJPEG];
    if (!jpeg) { send(cfd, HTTP_404, strlen(HTTP_404), 0); close(cfd); return; }

    NSString *hdr = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\n"
         "Content-Type: image/jpeg\r\n"
         "Content-Length: %lu\r\n"
         "Access-Control-Allow-Origin: *\r\n\r\n",
        (unsigned long)jpeg.length];
    send(cfd, hdr.UTF8String, strlen(hdr.UTF8String), 0);
    send(cfd, jpeg.bytes, jpeg.length, 0);
    close(cfd);
}

// ---------------------------------------------------------------------------
#pragma mark /info  — JSON device metadata
// ---------------------------------------------------------------------------

- (void)_serveInfo:(int)cfd {
    NSDictionary *info   = [DeviceInfo currentInfo];
    NSData       *json   = [NSJSONSerialization dataWithJSONObject:info options:0 error:nil];

    NSString *hdr = [NSString stringWithFormat:
        HTTP_200_JSON
        "Content-Length: %lu\r\n\r\n",
        (unsigned long)json.length];
    send(cfd, hdr.UTF8String, strlen(hdr.UTF8String), 0);
    send(cfd, json.bytes, json.length, 0);
    close(cfd);
}

@end

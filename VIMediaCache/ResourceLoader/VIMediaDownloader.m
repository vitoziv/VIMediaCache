//
//  VIMediaDownloader.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VIMediaDownloader.h"
#import "VIContentInfo.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "VICacheSessionManager.h"

#import "VIMediaCacheWorker.h"
#import "VICacheManager.h"
#import "VICacheAction.h"

@protocol  VIURLSessionDelegateObjectDelegate <NSObject>

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error;

@end

@interface VIURLSessionDelegateObject : NSObject <NSURLSessionDelegate>

- (instancetype)initWithDelegate:(id<VIURLSessionDelegateObjectDelegate>)delegate;

@property (nonatomic, weak) id<VIURLSessionDelegateObjectDelegate> delegate;

@end

@implementation VIURLSessionDelegateObject

- (instancetype)initWithDelegate:(id<VIURLSessionDelegateObjectDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    [self.delegate URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    [self.delegate URLSession:session dataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    [self.delegate URLSession:session task:task didCompleteWithError:error];
}

@end

@class VIActionWorker;

@protocol VIActionWorkerDelegate <NSObject>

- (void)actionWorker:(VIActionWorker *)actionWorker didReceiveResponse:(NSURLResponse *)response;
- (void)actionWorker:(VIActionWorker *)actionWorker didReceiveData:(NSData *)data isLocal:(BOOL)isLocal;
- (void)actionWorker:(VIActionWorker *)actionWorker didFinishWithError:(NSError *)error;

@end

@interface VIActionWorker : NSObject <VIURLSessionDelegateObjectDelegate>

@property (nonatomic, strong) NSMutableArray<VICacheAction *> *actions;
- (instancetype)initWithActions:(NSArray<VICacheAction *> *)actions url:(NSURL *)url;

@property (nonatomic, weak) id<VIActionWorkerDelegate> delegate;

- (void)start;
- (void)cancel;


@property (nonatomic, getter=isCancelled) BOOL cancelled;

@property (nonatomic, strong) VIMediaCacheWorker *cacheWorker;
@property (nonatomic, strong) NSURL *url;

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) VIURLSessionDelegateObject *sessionDelegateObject;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic) NSInteger startOffset;

@end

@implementation VIActionWorker

- (void)dealloc {
    [self cancel];
}

- (instancetype)initWithActions:(NSArray<VICacheAction *> *)actions url:(NSURL *)url{
    self = [super init];
    if (self) {
        _actions = [actions mutableCopy];
        NSString *filePath = [VICacheManager cachedFilePathForURL:url];
        _cacheWorker = [VIMediaCacheWorker inMemoryCacheWorkerWithFilePath:filePath];
        _url = url;
    }
    return self;
}

- (void)start {
    [self processActions];
}

- (void)cancel {
    if (_session) {
        [self.session invalidateAndCancel];
    }
    self.cancelled = YES;
}

- (VIURLSessionDelegateObject *)sessionDelegateObject {
    if (!_sessionDelegateObject) {
        _sessionDelegateObject = [[VIURLSessionDelegateObject alloc] initWithDelegate:self];
    }
    
    return _sessionDelegateObject;
}

- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self.sessionDelegateObject delegateQueue:[VICacheSessionManager shared].downloadQueue];
        _session = session;
    }
    return _session;
}

- (void)processActions {
    if (self.isCancelled) {
        return;
    }
    
    VICacheAction *action = [self.actions firstObject];
    if (!action) {
        if ([self.delegate respondsToSelector:@selector(actionWorker:didFinishWithError:)]) {
            [self.delegate actionWorker:self didFinishWithError:nil];
        }
        [self notifyDownloadProgress];
        return;
    }
    [self.actions removeObjectAtIndex:0];
    
    if (action.actionType == VICacheAtionTypeLocal) {
        NSData *data = [self.cacheWorker cachedDataForRange:action.range];
        if ([self.delegate respondsToSelector:@selector(actionWorker:didReceiveData:isLocal:)]) {
            [self.delegate actionWorker:self didReceiveData:data isLocal:YES];
        }
        [self processActions];
    } else {
        long long fromOffset = action.range.location;
        long long endOffset = action.range.location + action.range.length - 1;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
        request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
        NSString *range = [NSString stringWithFormat:@"Bytes=%lld-%lld", fromOffset, endOffset];
        [request setValue:range forHTTPHeaderField:@"Range"];
        self.startOffset = action.range.location;
        self.task = [self.session dataTaskWithRequest:request];
        [self.task resume];
    }
}

- (void)notifyDownloadProgress {
    VICacheConfiguration *configuration = self.cacheWorker.cacheConfiguration;
    [[NSNotificationCenter defaultCenter] postNotificationName:VICacheManagerDidUpdateCacheNotification
                                                        object:self
                                                      userInfo:@{
                                                                 VICacheURLKey: configuration.url ?: [NSNull null],
                                                                 VICacheFragmentsKey: configuration.cacheFragments,
                                                                 VICacheContentLengthKey: @(configuration.contentInfo.contentLength)
                                                                 }];
}

#pragma mark - VIURLSessionDelegateObjectDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSString *mimeType = response.MIMEType;
    // Only download video/audio data
    if ([mimeType rangeOfString:@"video/"].location == NSNotFound &&
        [mimeType rangeOfString:@"audio/"].location == NSNotFound) {
        completionHandler(NSURLSessionResponseCancel);
    } else {
        if ([self.delegate respondsToSelector:@selector(actionWorker:didReceiveResponse:)]) {
            [self.delegate actionWorker:self didReceiveResponse:response];
        }
        [self.cacheWorker startWritting];
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    if (self.isCancelled) {
        NSRange range = NSMakeRange(self.startOffset, data.length);
        NSLog(@"!!! cancel %@: %@, cache data: %@, request: %@", dataTask, dataTask.originalRequest.allHTTPHeaderFields, NSStringFromRange(range), dataTask.currentRequest.allHTTPHeaderFields);
        return;
    }
    NSRange range = NSMakeRange(self.startOffset, data.length);
    [self.cacheWorker cacheData:data forRange:range];
    self.startOffset += data.length;
    if ([self.delegate respondsToSelector:@selector(actionWorker:didReceiveData:isLocal:)]) {
        [self.delegate actionWorker:self didReceiveData:data isLocal:NO];
    }
    
    [self notifyDownloadProgress];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    if (error) {
        if (error.code != NSURLErrorCancelled) {
            if ([self.delegate respondsToSelector:@selector(actionWorker:didFinishWithError:)]) {
                [self.delegate actionWorker:self didFinishWithError:error];
            }
            NSLog(@"request error %@, request header %@", error, task.currentRequest.allHTTPHeaderFields);
        } else {
            // Cancelled because of stop loading.
        }
    } else {
        [self processActions];
    }
    [self.cacheWorker finishWritting];
    [self.cacheWorker save];
}

@end

@interface VIMediaDownloader () <VIActionWorkerDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *task;

@property (nonatomic, strong) VIMediaCacheWorker *cacheWorker;
@property (nonatomic, strong) VIActionWorker *actionWorker;

@property (nonatomic) BOOL downloadToEnd;

@end

@implementation VIMediaDownloader

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _url = url;
        
        NSString *filePath = [VICacheManager cachedFilePathForURL:url];
        _cacheWorker = [VIMediaCacheWorker inMemoryCacheWorkerWithFilePath:filePath];
        _info = _cacheWorker.cacheConfiguration.contentInfo;
    }
    return self;
}

- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return _session;
}

- (void)downloadTaskFromOffset:(unsigned long long)fromOffset
                        length:(NSInteger)length
                         toEnd:(BOOL)toEnd {
    NSRange range = NSMakeRange(fromOffset, length);
    
    if (toEnd) {
        range.length = self.cacheWorker.cacheConfiguration.contentInfo.contentLength - range.location;
    }
    
    NSLog(@"request range: %@", NSStringFromRange(range));
    NSArray *actions = [self.cacheWorker cachedDataActionsForRange:range];

    self.actionWorker = [[VIActionWorker alloc] initWithActions:actions url:self.url];
    self.actionWorker.delegate = self;
    [self.actionWorker start];
}

- (void)downloadFromStartToEnd {
    self.downloadToEnd = YES;
    NSRange range = NSMakeRange(0, 2);
    NSArray *actions = [self.cacheWorker cachedDataActionsForRange:range];

    self.actionWorker = [[VIActionWorker alloc] initWithActions:actions url:self.url];
    self.actionWorker.delegate = self;
    [self.actionWorker start];
}

- (void)cancel {
    self.actionWorker.delegate = nil;
    [self.actionWorker cancel];
    self.actionWorker = nil;
}

- (void)invalidateAndCancel {
    self.actionWorker.delegate = nil;
    [self.actionWorker cancel];
    self.actionWorker = nil;
}

#pragma mark - VIActionWorkerDelegate

- (void)actionWorker:(VIActionWorker *)actionWorker didReceiveResponse:(NSURLResponse *)response {
    if (!self.info) {
        VIContentInfo *info = [VIContentInfo new];
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
            NSString *acceptRange = HTTPURLResponse.allHeaderFields[@"Accept-Ranges"];
            info.byteRangeAccessSupported = [acceptRange isEqualToString:@"bytes"];
            info.contentLength = [[[HTTPURLResponse.allHeaderFields[@"Content-Range"] componentsSeparatedByString:@"/"] lastObject] longLongValue];
        }
        NSString *mimeType = response.MIMEType;
        CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
        info.contentType = CFBridgingRelease(contentType);
        self.info = info;
        
        [self.cacheWorker setContentInfo:info];
        self.cacheWorker.cacheConfiguration.url = response.URL;
    }
    
    if ([self.delegate respondsToSelector:@selector(mediaDownloader:didReceiveResponse:)]) {
        [self.delegate mediaDownloader:self didReceiveResponse:response];
    }
}

- (void)actionWorker:(VIActionWorker *)actionWorker didReceiveData:(NSData *)data isLocal:(BOOL)isLocal {
    if ([self.delegate respondsToSelector:@selector(mediaDownloader:didReceiveData:)]) {
        [self.delegate mediaDownloader:self didReceiveData:data];
    }
}

- (void)actionWorker:(VIActionWorker *)actionWorker didFinishWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(mediaDownloader:didFinishedWithError:)]) {
        [self.delegate mediaDownloader:self didFinishedWithError:error];
    }
    
    if (!error && self.downloadToEnd) {
        self.downloadToEnd = NO;
        [self downloadTaskFromOffset:2 length:self.cacheWorker.cacheConfiguration.contentInfo.contentLength - 2 toEnd:YES];
    }
}

@end

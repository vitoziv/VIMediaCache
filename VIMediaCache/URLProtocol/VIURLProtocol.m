//
//  VIURLProtocol.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VIURLProtocol.h"
#import "VIMediaCacheWorker.h"
#import "VICacheAction.h"
#import "VICacheSessionManager.h"
#import "VICacheManager.h"

static NSString *const VIURLProtocolHandledKey = @"VIURLProtocolHandledKey";
static NSString *const VIURLRequestRangeKey = @"VIURLRequestRangeKey";
static NSString *const VIURLRequestToEndKey = @"VIURLRequestToEndKey";

@interface VIURLProtocol () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) VIMediaCacheWorker *cacheWorker;
@property (nonatomic, strong) NSMutableArray<VICacheAction *> *restActions;

@property (nonatomic, strong) NSMutableArray *pendingRequests;

@property (nonatomic) NSInteger startOffset;

@end

@implementation VIURLProtocol

+ (void)setRequestRange:(NSRange)range inRequest:(NSMutableURLRequest *)request {
    [NSURLProtocol setProperty:NSStringFromRange(range) forKey:VIURLRequestRangeKey inRequest:request];
}

+ (NSRange)requestRagneInRequest:(NSMutableURLRequest *)request {
    NSString *rangeStr = [NSURLProtocol propertyForKey:VIURLRequestRangeKey inRequest:request];
    if (rangeStr) {
        NSRange range = NSRangeFromString(rangeStr);
        return range;
    }
    return NSMakeRange(NSNotFound, 0);
}

+ (void)setRequestToEndInRequest:(NSMutableURLRequest *)request {
    [NSURLProtocol setProperty:@(YES) forKey:VIURLRequestToEndKey inRequest:request];
}

+ (BOOL)requestToEndInRequest:(NSMutableURLRequest *)request {
    NSNumber *toEnd = [NSURLProtocol propertyForKey:VIURLRequestToEndKey inRequest:request];
    return [toEnd boolValue];
}

#pragma mark - Override

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

+ (BOOL)canInitWithTask:(NSURLSessionTask *)task {
    // Should not load task, if the same task has already loaded.
    if ([NSURLProtocol propertyForKey:VIURLProtocolHandledKey inRequest:task.originalRequest]) {
        return NO;
    }
    
    return YES;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // Should not load request, if the same request has already loaded.
    if ([NSURLProtocol propertyForKey:VIURLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    
    return YES;
}

- (void)startLoading {
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:VIURLProtocolHandledKey inRequest:newRequest];
    
    //    NSLog(@"%@ start loading request %@", self, self.request);
    __weak typeof(self)weakSelf = self;
    @synchronized (self.pendingRequests) {
        NSURLRequest *request = weakSelf.request;
        [weakSelf.pendingRequests addObject:request];
        
        if (weakSelf.pendingRequests.count == 1) {
            [weakSelf startRequest:request];
        }
    }
}

- (void)stopLoading {
    [self.cacheWorker save];
    self.cacheWorker = nil;
    [self.restActions removeAllObjects];
    [self.session invalidateAndCancel];
    self.session = nil;
}

#pragma mark - Download Logic

- (void)startRequest:(NSURLRequest *)request {
    if ([request.HTTPMethod isEqualToString:@"HEAD"]) {
        NSURLResponse *response = [self.cacheWorker cachedResponse];
        if (!response) {
            [[self.session dataTaskWithRequest:request] resume];
        } else {
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
            [self.client URLProtocolDidFinishLoading:self];
            [self consumePendingRequestIfNeed];
        }
        return;
    }
    
    
    
    NSRange requestRange = [self requestRange];
    
    long long expectedContentLength = self.cacheWorker.cachedResponse.expectedContentLength;
    if (requestRange.location + requestRange.length > expectedContentLength) {
        NSLog(@"too big reset range: %@, excpetLength: %@", NSStringFromRange(requestRange), @(expectedContentLength));
    }
    
    BOOL toEnd = [VIURLProtocol requestToEndInRequest:self.request];
    if (toEnd) {
        NSLog(@"request to end");
        requestRange.length = (expectedContentLength - requestRange.location);
    }
    
    NSURLResponse *response = [self.cacheWorker cachedResponseForRequestRange:requestRange];
    if (!response) {
        [[self.session dataTaskWithRequest:request] resume];
        return;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    });
    
    self.restActions = [[self.cacheWorker cachedDataActionsForRange:requestRange] mutableCopy];
    
    [self processActions];
}

- (void)processActions {
    VICacheAction *action = [self.restActions firstObject];
    if (!action) {
        [self.client URLProtocolDidFinishLoading:self];
        [self consumePendingRequestIfNeed];
        [self notifyDownloadProgress];
        return;
    }
    [self.restActions removeObjectAtIndex:0];
    
    if (action.actionType == VICacheAtionTypeLocal) {
        NSData *cachedData = [self.cacheWorker cachedDataForRange:action.range];
        [self.client URLProtocol:self didLoadData:cachedData];
        [self processActions];
    } else {
        long long fromOffset = action.range.location;
        long long endOffset = action.range.location + action.range.length - 1;
        NSMutableURLRequest *request = [self.request mutableCopy];
        NSString *range = [NSString stringWithFormat:@"Bytes=%lld-%lld", fromOffset, endOffset];
        [request setValue:range forHTTPHeaderField:@"Range"];
        self.startOffset = action.range.location;
        [[self.session dataTaskWithRequest:request] resume];
    }
}

- (void)notifyDownloadProgress {
    VICacheConfiguration *configuration = self.cacheWorker.cacheConfiguration;
    NSLog(@"notifyDownloadProgress %@, fragments: %@, exceptLength: %@", @(configuration.progress), configuration.cacheFragments, @(configuration.response.expectedContentLength));
    [[NSNotificationCenter defaultCenter] postNotificationName:VICacheManagerDidUpdateCacheNotification
                                                        object:self
                                                      userInfo:@{
                                                                 VICacheURLKey: configuration.response.URL ?: [NSNull null],
                                                                 VICacheFragmentsKey: configuration.cacheFragments,
                                                                 VICacheContentLengthKey: @(configuration.response.expectedContentLength)
                                                                 }];
}

#pragma mark - Pending Request

- (void)consumePendingRequestIfNeed {
    __weak typeof(self)weakSelf = self;
    @synchronized (self.pendingRequests) {
        if (weakSelf.pendingRequests.count > 0) {
            [weakSelf.pendingRequests removeObjectAtIndex:0];
        }
        if (weakSelf.pendingRequests.count > 0) {
            NSURLRequest *request = [weakSelf.pendingRequests firstObject];
            [weakSelf startRequest:request];
        }
    }
}

#pragma mark - Cache

- (NSRange)requestRange {
    NSRange range = [VIURLProtocol requestRagneInRequest:self.request];
    
    return range;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    if (!self.cacheWorker.cachedResponse) {
        [self.cacheWorker setCacheResponse:response];
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    }
    
    [self.cacheWorker startWritting];
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    NSRange range = NSMakeRange(self.startOffset, data.length);
    [self.cacheWorker cacheData:data forRange:range];
    self.startOffset += data.length;
    [self.client URLProtocol:self didLoadData:data];
    
    [self notifyDownloadProgress];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    if (error) {
        if (error.code != NSURLErrorCancelled) {
            [self.client URLProtocol:self didFailWithError:error];
            NSLog(@"request error %@, request header %@", error, task.currentRequest.allHTTPHeaderFields);
        } else {
            // Cancelled because of stop loading. According to -(void)stopLoading method description, we should stop sending notifications to the client
        }
        
        [self consumePendingRequestIfNeed];
    } else {
        [self processActions];
    }
    [self.cacheWorker finishWritting];
    [self.cacheWorker save];
}

#pragma mark - Getter

- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSOperationQueue *queue = [VICacheSessionManager shared].downloadQueue;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
    }
    return _session;
}

- (VIMediaCacheWorker *)cacheWorker {
    if (!_cacheWorker) {
        NSString *filePath = [VICacheManager cachedFilePathForURL:self.request.URL];
        _cacheWorker = [VIMediaCacheWorker inMemoryCacheWorkerWithFilePath:filePath];
        NSRange requestRange = [self requestRange];
        _startOffset = requestRange.location;
    }
    return _cacheWorker;
}

- (NSMutableArray *)pendingRequests {
    if (!_pendingRequests) {
        _pendingRequests = [NSMutableArray array];
    }
    return _pendingRequests;
}

@end

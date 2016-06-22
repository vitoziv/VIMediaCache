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

static NSString *const VIURLProtocolHandledKey = @"VIURLProtocolHandledKey";

@interface VIURLProtocol () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) VIMediaCacheWorker *cacheWorker;
@property (nonatomic, strong) NSMutableArray<VICacheAction *> *restActions;

@property (nonatomic, strong) NSMutableArray *pendingRequests;

@property (nonatomic) NSInteger startOffset;

@end

@implementation VIURLProtocol

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
        NSLog(@"finishLoading has not action");
        [self consumePendingRequestIfNeed];
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
    NSString *range = self.request.allHTTPHeaderFields[@"range"];
    if (range) {
        range = [range substringFromIndex:6];
        NSArray *rangeArr = [range componentsSeparatedByString:@"-"];
        NSInteger startOffset = [[rangeArr firstObject] integerValue];
        NSInteger endOffset = [[rangeArr lastObject] integerValue];
        return NSMakeRange(startOffset, endOffset - startOffset + 1);
    }
    return NSMakeRange(NSNotFound, 0);
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
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    NSRange range = NSMakeRange(self.startOffset, data.length);
    [self.cacheWorker cacheData:data forRange:range];
    self.startOffset += data.length;
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    if (error) {
        if (error.code != NSURLErrorCancelled) {
            [self.client URLProtocol:self didFailWithError:error];
            NSLog(@"request error %@, request header %@", error, task.currentRequest.allHTTPHeaderFields);
        } else {
            NSLog(@"cancel request %@", task.currentRequest.allHTTPHeaderFields);
        }
        
        [self consumePendingRequestIfNeed];
    } else {
        [self.cacheWorker save];
        [self processActions];
    }
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
        NSString *cacheName = [self.request.URL lastPathComponent];
        _cacheWorker = [VIMediaCacheWorker inMemoryCacheWorkerWithCacheName:cacheName];
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

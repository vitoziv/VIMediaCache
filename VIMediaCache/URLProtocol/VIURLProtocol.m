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

@interface VIURLProtocol () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) VIMediaCacheWorker *cacheWorker;
@property (nonatomic, strong) NSMutableArray<VICacheAction *> *restActions;

@property (nonatomic) NSInteger startOffset;


@end

@implementation VIURLProtocol

- (void)commonInit {
    if (!_session) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSOperationQueue *queue = [VICacheSessionManager shared].downloadQueue;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
    }
    
    if (!_cacheWorker) {
        NSString *cacheName = [self.request.URL lastPathComponent];
        _cacheWorker = [VIMediaCacheWorker inMemoryCacheWorkerWithCacheName:cacheName];
        NSRange requestRange = [self requestRange];
        _startOffset = requestRange.location;
    }
}

#pragma mark - Override

- (instancetype)initWithTask:(NSURLSessionTask *)task cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client {
    self = [super initWithTask:task cachedResponse:cachedResponse client:client];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client {
    self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
    if (self) {
        [self commonInit];
    }
    return self;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

+ (BOOL)canInitWithTask:(NSURLSessionTask *)task {
    if ([task.currentRequest.HTTPMethod isEqualToString:@"GET"] || [task.currentRequest.HTTPMethod isEqualToString:@"HEAD"]) {
        return YES;
    }
    
    return NO;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([request.HTTPMethod isEqualToString:@"GET"] || [request.HTTPMethod isEqualToString:@"HEAD"]) {
        return YES;
    }
    
    return NO;
}

- (void)startLoading {
    if ([self.request.HTTPMethod isEqualToString:@"HEAD"]) {
        NSURLResponse *response = [self.cacheWorker cachedResponse];
        if (!response) {
            [[self.session dataTaskWithRequest:self.request] resume];
        } else {
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
            [self.client URLProtocolDidFinishLoading:self];
        }
        return;
    }

    NSRange requestRange = [self requestRange];
    NSURLResponse *response = [self.cacheWorker cachedResponseForRequestRange:requestRange];
    if (!response) {
        [[self.session dataTaskWithRequest:self.request] resume];
        return;
    }
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    self.restActions = [[self.cacheWorker cachedDataActionsForRange:requestRange] mutableCopy];
    [self processActions];
}

- (void)stopLoading {
    [self.cacheWorker save];
    [self.restActions removeAllObjects];
    [self.session invalidateAndCancel];
}

#pragma mark - Download Logic

- (void)processActions {
    VICacheAction *action = [self.restActions firstObject];
    if (!action) {
        [self.client URLProtocolDidFinishLoading:self];
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
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.cacheWorker save];
        [self processActions];
    }
}

@end

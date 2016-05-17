//
//  MTMCResoureLoader.m
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import "MTMCResourceLoader.h"
#import "MTMCMediaDownloader.h"
#import "MTMCResourceLoadingRequestWorker.h"
#import "MTMCContentInfo.h"

NSString * const MCResourceLoaderErrorDomain = @"LSFilePlayerResourceLoaderErrorDomain";

@interface MTMCResourceLoader () <MTMCResourceLoadingRequestWorkerDelegate>

@property (nonatomic, strong) MTMCMediaDownloader *mediaDownloader;
@property (nonatomic, strong) NSMutableDictionary *pendingRequestWorkers;
@property (nonatomic, strong) NSMutableArray<AVAssetResourceLoadingRequest *> *pendingRequests;

@property (nonatomic, strong) MTMCContentInfo *info;
@property (nonatomic, getter=isCancelled) BOOL cancelled;

@end

@implementation MTMCResourceLoader


- (void)dealloc {
    [_mediaDownloader cancelAllTasks];
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _mediaDownloader = [[MTMCMediaDownloader alloc] initWithURL:url];
        _pendingRequestWorkers = [NSMutableDictionary dictionary];
        _pendingRequests = [NSMutableArray array];
        
        [self prepareForLoading];
    }
    return self;
}

- (instancetype)init {
    NSAssert(NO, @"Use - initWithURL: instead");
    return nil;
}

- (void)prepareForLoading {
    __weak typeof(self)weakSelf = self;
    NSURLSessionDataTask *task = [self.mediaDownloader fetchFileInfoTaskWithCompletion:^(MTMCContentInfo *info, NSError *error) {
        if (!error) {
            weakSelf.info = info;
            [weakSelf.pendingRequests enumerateObjectsUsingBlock:^(AVAssetResourceLoadingRequest * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [weakSelf addRequest:obj];
            }];
        } else {
            weakSelf.cancelled = YES;
            [weakSelf.pendingRequests enumerateObjectsUsingBlock:^(AVAssetResourceLoadingRequest * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [obj finishLoadingWithError:error];
            }];
        }
    }];
    [task resume];
}

- (void)addRequest:(AVAssetResourceLoadingRequest *)request {
    if (!self.isCancelled) {
        if (!self.info) {
            [self.pendingRequests addObject:request];
            return;
        }
        
        [self.pendingRequestWorkers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, MTMCResourceLoadingRequestWorker * _Nonnull obj, BOOL * _Nonnull stop) {
            [obj cancel];
        }];
        
        // Fullfill content information
        AVAssetResourceLoadingContentInformationRequest *contentInformationRequest = request.contentInformationRequest;
        contentInformationRequest.byteRangeAccessSupported = self.info.byteRangeAccessSupported;
        contentInformationRequest.contentType = self.info.contentType;
        contentInformationRequest.contentLength = self.info.contentLength;
        
        NSString *key = [self keyForRequest:request];
        MTMCResourceLoadingRequestWorker *pendingRequestWorker = self.pendingRequestWorkers[key];
        if (pendingRequestWorker) {
            [self removeRequest:pendingRequestWorker.request];
        }
        
        [self startWorkerWithRequest:request];
    } else {
        if (!request.isFinished) {
            [request finishLoadingWithError:[self loaderCancelledError]];
        }
    }
}

- (void)removeRequest:(AVAssetResourceLoadingRequest *)request {
    NSString *key = [self keyForRequest:request];
    MTMCResourceLoadingRequestWorker *requestWorker = self.pendingRequestWorkers[key];
    [requestWorker finish];
    
    [self.pendingRequestWorkers removeObjectForKey:key];
}

- (void)cancel {
    self.cancelled = YES;
    [self.mediaDownloader cancelAllTasks];
}

#pragma mark - MTMCResourceLoadingRequestWorkerDelegate

- (void)resourceLoadingRequestWorkerDidComplete:(MTMCResourceLoadingRequestWorker *)requestWorker {
    [self removeRequest:requestWorker.request];
    
    // Start previous canceled request
    NSDictionary *pendingRequestWorkers = [self.pendingRequestWorkers copy];
    if (pendingRequestWorkers.count > 0) {
        NSString *key = [[pendingRequestWorkers allKeys] lastObject];
        MTMCResourceLoadingRequestWorker *previousRequestWorker = (MTMCResourceLoadingRequestWorker *)pendingRequestWorkers[key];
        [self startWorkerWithRequest:previousRequestWorker.request];
    }
}

#pragma mark - Helper

- (void)startWorkerWithRequest:(AVAssetResourceLoadingRequest *)request {
    NSString *key = [self keyForRequest:request];
    MTMCResourceLoadingRequestWorker *requestWorker = [[MTMCResourceLoadingRequestWorker alloc] initWithMediaDownloader:self.mediaDownloader
                                                                                                 resourceLoadingRequest:request];
    requestWorker.delegate = self;
    self.pendingRequestWorkers[key] = requestWorker;
    [requestWorker startWork];
}

- (NSString *)keyForRequest:(AVAssetResourceLoadingRequest *)request {
    return [NSString stringWithFormat:@"%@%@", request.request.URL.absoluteString, request.request.allHTTPHeaderFields[@"Range"]];
}

- (NSError *)loaderCancelledError{
    NSError *error = [[NSError alloc] initWithDomain:MCResourceLoaderErrorDomain
                                                code:-3
                                            userInfo:@{NSLocalizedDescriptionKey:@"Resource loader cancelled"}];
    return error;
}

@end

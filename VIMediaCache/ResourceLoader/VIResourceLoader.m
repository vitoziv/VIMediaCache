//
//  VIResoureLoader.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VIResourceLoader.h"
#import "VIMediaDownloader.h"
#import "VIResourceLoadingRequestWorker.h"
#import "VIContentInfo.h"

NSString * const MCResourceLoaderErrorDomain = @"LSFilePlayerResourceLoaderErrorDomain";

@interface VIResourceLoader () <VIResourceLoadingRequestWorkerDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) VIMediaDownloader *mediaDownloader;
@property (nonatomic, strong) NSMutableDictionary *pendingRequestWorkers;

@property (nonatomic, getter=isCancelled) BOOL cancelled;

@end

@implementation VIResourceLoader


- (void)dealloc {
    [_mediaDownloader invalidateAndCancel];
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _url = url;
        _mediaDownloader = [[VIMediaDownloader alloc] initWithURL:url];
        _pendingRequestWorkers = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)init {
    NSAssert(NO, @"Use - initWithURL: instead");
    return nil;
}

- (void)addRequest:(AVAssetResourceLoadingRequest *)request {
    if (!self.isCancelled) {
        [self.pendingRequestWorkers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, VIResourceLoadingRequestWorker * _Nonnull obj, BOOL * _Nonnull stop) {
            NSLog(@"finish request worker: %@", obj);
            [obj finish];
        }];
        [self.pendingRequestWorkers removeAllObjects];
        
        [self startWorkerWithRequest:request];
    } else {
        if (!request.isFinished) {
            [request finishLoadingWithError:[self loaderCancelledError]];
        }
    }
}

- (void)removeRequest:(AVAssetResourceLoadingRequest *)request {
    NSString *key = [self keyForRequest:request];
    VIResourceLoadingRequestWorker *requestWorker = self.pendingRequestWorkers[key];
    [requestWorker finish];
    
    [self.pendingRequestWorkers removeObjectForKey:key];
}

- (void)cancel {
    NSLog(@"%@, %@", self, NSStringFromSelector(_cmd));
    self.cancelled = YES;
    [self.mediaDownloader invalidateAndCancel];
}

#pragma mark - VIResourceLoadingRequestWorkerDelegate

- (void)resourceLoadingRequestWorkerDidComplete:(VIResourceLoadingRequestWorker *)requestWorker {
    [self removeRequest:requestWorker.request];
    
    // Start previous cancelled request
    NSDictionary *pendingRequestWorkers = [self.pendingRequestWorkers copy];
    if (pendingRequestWorkers.count > 0) {
        NSLog(@"*** try to start previous cancelled request");
        //        NSString *key = [[pendingRequestWorkers allKeys] lastObject];
        //        VIResourceLoadingRequestWorker *previousRequestWorker = (VIResourceLoadingRequestWorker *)pendingRequestWorkers[key];
        //        [self startWorkerWithRequest:previousRequestWorker.request];
    }
}

#pragma mark - Helper

- (void)startWorkerWithRequest:(AVAssetResourceLoadingRequest *)request {
    NSString *key = [self keyForRequest:request];
    VIResourceLoadingRequestWorker *requestWorker = [[VIResourceLoadingRequestWorker alloc] initWithMediaDownloader:self.mediaDownloader
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

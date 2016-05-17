//
//  MTMCResourceLoadingRequestWorker.m
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import "MTMCResourceLoadingRequestWorker.h"
#import "MTMCMediaDownloader.h"
#import "MTMCContentInfo.h"
@import AVFoundation;

@interface MTMCResourceLoadingRequestWorker () <MediaDownloaderDelegate>

@property (nonatomic, strong, readwrite) AVAssetResourceLoadingRequest *request;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, strong) MTMCMediaDownloader *mediaDownloader;

@end

@implementation MTMCResourceLoadingRequestWorker

- (instancetype)initWithMediaDownloader:(MTMCMediaDownloader *)mediaDownloader resourceLoadingRequest:(AVAssetResourceLoadingRequest *)request {
    self = [super init];
    if (self) {
        _mediaDownloader = mediaDownloader;
        _request = request;
        AVAssetResourceLoadingDataRequest *dataRequest = request.dataRequest;
        unsigned long long offset = dataRequest.currentOffset;
        unsigned long long length = dataRequest.requestedLength;
        _task = [self.mediaDownloader downloadTaskWithDelegate:self fromOffset:offset length:length];
    }
    return self;
}

- (void)startWork {
    [self.task resume];
}

- (void)cancel {
    [self.task cancel];
}

- (void)finish {
    [self.mediaDownloader cancelTask:self.task];
    if (!self.request.isFinished) {
        [self.request finishLoadingWithError:[self loaderCancelledError]];
    }
}

- (NSError *)loaderCancelledError{
    NSError *error = [[NSError alloc] initWithDomain:@"com.resourceloader"
                                                code:-3
                                            userInfo:@{NSLocalizedDescriptionKey:@"Resource loader cancelled"}];
    return error;
}

#pragma mark - MediaDownloaderDelegate

- (void)mediaDownloader:(MTMCMediaDownloader *)downloader didReceiveData:(NSData *)data {
    [self.request.dataRequest respondWithData:data];
}

- (void)mediaDownloader:(MTMCMediaDownloader *)downloader didFinishedWithError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) {
        NSLog(@"Cancel task %@", self.task.currentRequest.allHTTPHeaderFields[@"Range"]);
        return;
    }
    
    if (!error) {
        [self.request finishLoading];
    } else {
        [self.request finishLoadingWithError:error];
    }
    
    [self.delegate resourceLoadingRequestWorkerDidComplete:self];
}

@end

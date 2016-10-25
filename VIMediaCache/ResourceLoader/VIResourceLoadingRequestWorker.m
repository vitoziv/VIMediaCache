//
//  VIResourceLoadingRequestWorker.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VIResourceLoadingRequestWorker.h"
#import "VIMediaDownloader.h"
#import "VIContentInfo.h"

@import MobileCoreServices;
@import AVFoundation;
@import UIKit;

@interface VIResourceLoadingRequestWorker () <MediaDownloaderDelegate>

@property (nonatomic, strong, readwrite) AVAssetResourceLoadingRequest *request;
@property (nonatomic, strong) VIMediaDownloader *mediaDownloader;

@end

@implementation VIResourceLoadingRequestWorker

- (instancetype)initWithMediaDownloader:(VIMediaDownloader *)mediaDownloader resourceLoadingRequest:(AVAssetResourceLoadingRequest *)request {
    self = [super init];
    if (self) {
        _mediaDownloader = mediaDownloader;
        _mediaDownloader.delegate = self;
        _request = request;
        
        [self fullfillContentInfo];
    }
    return self;
}

- (void)startWork {
    AVAssetResourceLoadingDataRequest *dataRequest = self.request.dataRequest;
    
    long long offset = dataRequest.requestedOffset;
    NSInteger length = dataRequest.requestedLength;
    if (dataRequest.currentOffset != 0) {
        offset = dataRequest.currentOffset;
    }
    
    BOOL toEnd = NO;
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 9.0) {
        if (dataRequest.requestsAllDataToEndOfResource) {
            toEnd = YES;
        }
    }
    [self.mediaDownloader downloadTaskFromOffset:offset length:length toEnd:toEnd];
}

- (void)cancel {
    [self.mediaDownloader cancel];
}

- (void)finish {
    [self.mediaDownloader cancel];
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

- (void)fullfillContentInfo {
    AVAssetResourceLoadingContentInformationRequest *contentInformationRequest = self.request.contentInformationRequest;
    if (self.mediaDownloader.info && !contentInformationRequest.contentType) {
        // Fullfill content information
        contentInformationRequest.contentType = self.mediaDownloader.info.contentType;
        contentInformationRequest.contentLength = self.mediaDownloader.info.contentLength;
        contentInformationRequest.byteRangeAccessSupported = self.mediaDownloader.info.byteRangeAccessSupported;
    }
}

#pragma mark - MediaDownloaderDelegate

- (void)mediaDownloader:(VIMediaDownloader *)downloader didReceiveResponse:(NSURLResponse *)response {
    [self fullfillContentInfo];
}

- (void)mediaDownloader:(VIMediaDownloader *)downloader didReceiveData:(NSData *)data {
    [self.request.dataRequest respondWithData:data];
}

- (void)mediaDownloader:(VIMediaDownloader *)downloader didFinishedWithError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) {
        NSLog(@"Cancel dwonload %@", self.request.dataRequest);
        return;
    }
    
    AVAssetResourceLoadingDataRequest *dataRequest = self.request.dataRequest;
    NSLog(@"finish downloader, currentOffset: %@, requestedOffset: %@, requestedLength: %@", @(dataRequest.currentOffset), @(dataRequest.requestedOffset), @(dataRequest.requestedLength));
    if (!error) {
        [self.request finishLoading];
    } else {
        [self.request finishLoadingWithError:error];
    }
    
    [self.delegate resourceLoadingRequestWorkerDidComplete:self];
}

@end

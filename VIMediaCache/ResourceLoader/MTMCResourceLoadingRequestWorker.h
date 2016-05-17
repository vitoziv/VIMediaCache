//
//  MTMCResourceLoadingRequestWorker.h
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MTMCMediaDownloader, AVAssetResourceLoadingRequest;
@protocol MTMCResourceLoadingRequestWorkerDelegate;

@interface MTMCResourceLoadingRequestWorker : NSObject

- (instancetype)initWithMediaDownloader:(MTMCMediaDownloader *)mediaDownloader resourceLoadingRequest:(AVAssetResourceLoadingRequest *)request;

@property (nonatomic, weak) id<MTMCResourceLoadingRequestWorkerDelegate> delegate;

@property (nonatomic, strong, readonly) AVAssetResourceLoadingRequest *request;

- (void)startWork;
- (void)cancel;
- (void)finish;

@end

@protocol MTMCResourceLoadingRequestWorkerDelegate <NSObject>

- (void)resourceLoadingRequestWorkerDidComplete:(MTMCResourceLoadingRequestWorker *)requestWorker;

@end
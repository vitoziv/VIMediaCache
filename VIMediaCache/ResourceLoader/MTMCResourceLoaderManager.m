//
//  MTMCResourceLoaderManager.m
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import "MTMCResourceLoaderManager.h"
#import "MTMCResourceLoader.h"

static NSString *kCacheScheme = @"MTMediaCache";

@interface MTMCResourceLoaderManager ()

@property (nonatomic, strong) NSMutableDictionary<id<NSCoding>, MTMCResourceLoader *> *loaders;

@end

@implementation MTMCResourceLoaderManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _loaders = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest  {
    NSURL *resourceURL = [loadingRequest.request URL];
    if ([resourceURL.scheme isEqualToString:kCacheScheme]) {
        MTMCResourceLoader *loader = [self loaderForRequest:loadingRequest];
        if (!loader) {
            NSURLComponents *components = [NSURLComponents componentsWithString:resourceURL.absoluteString];
            NSURL *originURL;
            if ([components respondsToSelector:@selector(queryItems)]) {
                NSURLQueryItem *queryItem = [components.queryItems lastObject];
                originURL = [NSURL URLWithString:queryItem.value];
            } else {
                NSString *url = [[components.query componentsSeparatedByString:@"="] lastObject];
                originURL = [NSURL URLWithString:url];
            }
            loader = [[MTMCResourceLoader alloc] initWithURL:originURL];
            NSString *key = [self keyForResourceLoaderWithURL:resourceURL];
            self.loaders[key] = loader;
        }
        [loader addRequest:loadingRequest];
        return YES;
    }
    
    return NO;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    MTMCResourceLoader *loader = [self loaderForRequest:loadingRequest];
    [loader removeRequest:loadingRequest];
}

#pragma mark - Helper

- (NSString *)keyForResourceLoaderWithURL:(NSURL *)requestURL {
    if([requestURL.scheme isEqualToString:kCacheScheme]){
        NSString *s = requestURL.absoluteString;
        return s;
    }
    return nil;
}

- (MTMCResourceLoader *)loaderForRequest:(AVAssetResourceLoadingRequest *)request {
    NSString *requestKey = [self keyForResourceLoaderWithURL:request.request.URL];
    MTMCResourceLoader *loader = self.loaders[requestKey];
    return loader;
}

@end

@implementation MTMCResourceLoaderManager (Convenient)

+ (NSURL *)assetURLWithURL:(NSURL *)url {
    NSURLComponents *componnents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    componnents.scheme = kCacheScheme;
    
    NSString *appendStr = componnents.query.length > 0 ? @"&" : @"?";
    NSURL *assetURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@MCurl=%@", componnents.URL.absoluteString, appendStr, url.absoluteString]];
    
    return assetURL;
}

- (AVPlayerItem *)playerItemWithURL:(NSURL *)url {
    NSURL *assetURL = [MTMCResourceLoaderManager assetURLWithURL:url];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    [urlAsset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:urlAsset];
    if ([playerItem respondsToSelector:@selector(setCanUseNetworkResourcesForLiveStreamingWhilePaused:)]) {
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;
    }
    return playerItem;
}

@end

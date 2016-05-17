//
//  MTMCCacheSessionManager.m
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import "MTMCCacheSessionManager.h"

@interface MTMCCacheSessionManager ()

@property (nonatomic, strong) NSOperationQueue *downloadQueue;

@end

@implementation MTMCCacheSessionManager

+ (instancetype)shared {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.name = @"com.MTMediaCache.download";
        _downloadQueue = queue;
    }
    return self;
}

@end

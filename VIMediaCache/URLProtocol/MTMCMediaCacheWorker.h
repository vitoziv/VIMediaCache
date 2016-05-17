//
//  MTMCMediaCacheWorker.h
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MTMCCacheAction;

@interface MTMCMediaCacheWorker : NSObject

+ (instancetype)inMemoryCacheWorkerWithCacheName:(NSString *)cacheName;
- (instancetype)initWithCacheName:(NSString *)cacheName;

@property (nonatomic, strong, readonly) NSError *setupError; // Create fileHandler error, can't save/use cache

- (void)cacheData:(NSData *)data forRange:(NSRange)range;
- (NSArray<MTMCCacheAction *> *)cachedDataActionsForRange:(NSRange)range;
- (NSData *)cachedDataForRange:(NSRange)range;

- (void)setCacheResponse:(NSURLResponse *)response;
- (NSURLResponse *)cachedResponse;
- (NSURLResponse *)cachedResponseForRequestRange:(NSRange)range;

- (void)save;

@end

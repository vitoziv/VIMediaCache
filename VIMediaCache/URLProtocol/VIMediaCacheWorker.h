//
//  VIMediaCacheWorker.h
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VICacheConfiguration.h"

@class VICacheAction;

@interface VIMediaCacheWorker : NSObject

+ (instancetype)inMemoryCacheWorkerWithFilePath:(NSString *)filePath;
- (instancetype)initWithCacheFilePath:(NSString *)path;

@property (nonatomic, strong, readonly) VICacheConfiguration *cacheConfiguration;
@property (nonatomic, strong, readonly) NSError *setupError; // Create fileHandler error, can't save/use cache

- (void)cacheData:(NSData *)data forRange:(NSRange)range;
- (NSArray<VICacheAction *> *)cachedDataActionsForRange:(NSRange)range;
- (NSData *)cachedDataForRange:(NSRange)range;

- (void)setCacheResponse:(NSURLResponse *)response;
- (NSURLResponse *)cachedResponse;
- (NSURLResponse *)cachedResponseForRequestRange:(NSRange)range;

- (void)save;

@end

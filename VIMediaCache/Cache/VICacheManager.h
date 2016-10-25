//
//  VICacheManager.h
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VICacheConfiguration.h"

extern NSString *VICacheManagerDidUpdateCacheNotification;

extern NSString *VICacheURLKey;
extern NSString *VICacheFragmentsKey;
extern NSString *VICacheContentLengthKey;

@interface VICacheManager : NSObject

+ (void)setCacheDirectory:(NSString *)cacheDirectory;
+ (NSString *)cacheDirectory;


/**
 How often trigger `VICacheManagerDidUpdateCacheNotification` notification

 @param interval Minimum interval
 */
+ (void)setCacheUpdateNotifyInterval:(NSTimeInterval)interval;
+ (NSTimeInterval)cacheUpdateNotifyInterval;

+ (NSString *)cachedFilePathForURL:(NSURL *)url;
+ (VICacheConfiguration *)cacheConfigurationForURL:(NSURL *)url;


/**
 Calculate cached files size

 @param error
 @return files size, respresent by `byte`, if error occured return -1
 */
+ (unsigned long long)calculateCachedSizeWithError:(NSError **)error;
+ (void)cleanAllCacheWithError:(NSError **)error;
+ (void)cleanCacheForURL:(NSURL *)url error:(NSError **)error;

@end

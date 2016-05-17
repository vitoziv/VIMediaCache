//
//  MTMCCacheManager.h
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *MTMCCacheManagerDidUpdateCacheNotification;

extern NSString *MTMCCacheURLKey;
extern NSString *MTMCCacheFragmentsKey;
extern NSString *MTMCCacheContentLengthKey;

@interface MTMCCacheManager : NSObject

+ (void)setCacheDirectory:(NSString *)cacheDirectory;
+ (NSString *)cacheDirectory;

@end

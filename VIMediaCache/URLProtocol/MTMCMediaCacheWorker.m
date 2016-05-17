//
//  MTMCMediaCacheWorker.m
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import "MTMCMediaCacheWorker.h"
#import "MTMCCacheConfiguration.h"
#import "MTMCCacheAction.h"
#import "MTMCCacheManager.h"

static NSInteger const kPackageLength = 204800; // 200kb per package

@interface MTMCMediaCacheWorkerFactory : NSObject

@property (nonatomic, strong) NSMutableDictionary *memoryCacheWorkers;

@end

@implementation MTMCMediaCacheWorkerFactory

+ (instancetype)shared {
    static MTMCMediaCacheWorkerFactory *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.memoryCacheWorkers = [NSMutableDictionary dictionary];
    });
    
    return instance;
}

- (MTMCMediaCacheWorker *)cacheWorkerWithCacheName:(NSString *)cacheName {
    MTMCMediaCacheWorker *cacheWorker = self.memoryCacheWorkers[cacheName];
    if (!cacheWorker) {
        cacheWorker = [[MTMCMediaCacheWorker alloc] initWithCacheName:cacheName];
        self.memoryCacheWorkers[cacheName] = cacheWorker;
    }
    
    return cacheWorker;
}

@end

static NSString *kMCMediaCacheResponseKey = @"kMCMediaCacheResponseKey";


@interface MTMCMediaCacheWorker ()

@property (nonatomic, strong) NSFileHandle *readFileHandle;
@property (nonatomic, strong) NSFileHandle *writeFileHandle;
@property (nonatomic, strong, readwrite) NSError *setupError;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) MTMCCacheConfiguration *cacheConfiguration;

@property (nonatomic) long long currentOffset;

@end

@implementation MTMCMediaCacheWorker


- (void)dealloc {
    [_readFileHandle closeFile];
    [_writeFileHandle closeFile];
}

+ (instancetype)inMemoryCacheWorkerWithCacheName:(NSString *)cacheName {
    return [[MTMCMediaCacheWorkerFactory shared] cacheWorkerWithCacheName:cacheName];
}

- (instancetype)initWithCacheName:(NSString *)cacheName {
    self = [super init];
    if (self) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *cacheFolder = [MTMCCacheManager cacheDirectory];
        NSString *path = [cacheFolder stringByAppendingPathComponent:cacheName];
        _filePath = path;
        NSError *error;
        if (![fileManager fileExistsAtPath:cacheFolder]) {
            [fileManager createDirectoryAtPath:cacheFolder
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&error];
        }
        
        if (!error) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
            }
            NSURL *fileURL = [NSURL fileURLWithPath:path];
            _readFileHandle = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&error];
            if (!error) {
                _writeFileHandle = [NSFileHandle fileHandleForWritingToURL:fileURL error:&error];
                _cacheConfiguration = [MTMCCacheConfiguration configurationWithFileName:cacheName];
            }
        }
        
        _setupError = error;
    }
    return self;
}

- (void)cacheData:(NSData *)data forRange:(NSRange)range {
    @synchronized(self.writeFileHandle) {
        @try {
            [self.writeFileHandle seekToFileOffset:range.location];
            [self.writeFileHandle writeData:data];
            [self.cacheConfiguration addCacheFragment:range];
            [self save];
        } @catch (NSException *exception) {
            NSLog(@"write to file error");
        }
    }
}

- (NSData *)cachedDataForRange:(NSRange)range {
    @synchronized(self.readFileHandle) {
        @try {
            [self.readFileHandle seekToFileOffset:range.location];
            NSLog(@"cache fragments: %@, cachedDataForRange: %@", self.cacheConfiguration.cacheFragments, NSStringFromRange(range));
            NSData *data = [self.readFileHandle readDataOfLength:range.length]; // 空数据也会返回，所以如果 range 错误，会导致播放失效
            return data;
        } @catch (NSException *exception) {
            NSLog(@"read cached data error %@",exception);
        }
    }
    return nil;
}

- (NSArray<MTMCCacheAction *> *)cachedDataActionsForRange:(NSRange)range {
    NSArray *cachedFragments = [self.cacheConfiguration cacheFragments];
    NSMutableArray *actions = [NSMutableArray array];
    
    if (range.location == NSNotFound) {
        return [actions copy];
    }
    long long endOffset = range.location + range.length;
    // Delete header and footer not in range
    [cachedFragments enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange fragmentRange = obj.rangeValue;
        NSRange intersectionRange = NSIntersectionRange(range, fragmentRange);
        if (intersectionRange.length > 0) {
            NSInteger package = intersectionRange.length / kPackageLength;
            for (NSInteger i = 0; i <= package; i++) {
                MTMCCacheAction *action = [MTMCCacheAction new];
                action.actionType = MTMCCacheAtionTypeLocal;
                
                NSInteger offset = i * kPackageLength;
                NSInteger offsetLocation = intersectionRange.location + offset;
                NSInteger maxLocation = intersectionRange.location + intersectionRange.length;
                NSInteger length = (offsetLocation + kPackageLength) > maxLocation ? (maxLocation - offsetLocation) : kPackageLength;
                action.range = NSMakeRange(offsetLocation, length);
                
                NSLog(@"index: %@, range: %@", @(i), NSStringFromRange(action.range));
                [actions addObject:action];
            }
        } else if (fragmentRange.location >= endOffset) {
            *stop = YES;
        }
    }];
    
    if (actions.count == 0) {
        MTMCCacheAction *action = [MTMCCacheAction new];
        action.actionType = MTMCCacheAtionTypeRemote;
        action.range = range;
        [actions addObject:action];
    } else {
        // Add remote fragments
        NSMutableArray *localRemoteActions = [NSMutableArray array];
        [actions enumerateObjectsUsingBlock:^(MTMCCacheAction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSRange actionRange = obj.range;
            if (idx == 0) {
                if (range.location < actionRange.location) {
                    MTMCCacheAction *action = [MTMCCacheAction new];
                    action.actionType = MTMCCacheAtionTypeRemote;
                    action.range = NSMakeRange(range.location, actionRange.location - range.location);
                    [localRemoteActions addObject:action];
                }
                [localRemoteActions addObject:obj];
            } else {
                MTMCCacheAction *lastAction = [localRemoteActions lastObject];
                long long lastOffset = lastAction.range.location + lastAction.range.length;
                if (actionRange.location > lastOffset) {
                    MTMCCacheAction *action = [MTMCCacheAction new];
                    action.actionType = MTMCCacheAtionTypeRemote;
                    action.range = NSMakeRange(lastOffset, actionRange.location - lastOffset);
                    [localRemoteActions addObject:action];
                }
                [localRemoteActions addObject:obj];
            }
            
            if (idx == actions.count - 1) {
                long long localEndOffset = actionRange.location + actionRange.length;
                if (endOffset > localEndOffset) {
                    MTMCCacheAction *action = [MTMCCacheAction new];
                    action.actionType = MTMCCacheAtionTypeRemote;
                    action.range = NSMakeRange(localEndOffset, endOffset - localEndOffset);
                    [localRemoteActions addObject:action];
                }
            }
        }];
        
        actions = localRemoteActions;
    }
    
    return [actions copy];
}

- (void)setCacheResponse:(NSURLResponse *)response {
    @synchronized (self.writeFileHandle) {
        self.cacheConfiguration.response = response;
        
        [self.writeFileHandle truncateFileAtOffset:response.expectedContentLength];
        [self.writeFileHandle synchronizeFile];
    }
}

- (NSURLResponse *)cachedResponse {
    return self.cacheConfiguration.response;
}

- (NSURLResponse *)cachedResponseForRequestRange:(NSRange)range {
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)[self cachedResponse];
    if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
        return response;
    }
    
    NSMutableDictionary *allHeaderFields = [response.allHeaderFields mutableCopy];
    allHeaderFields[@"Content-Range"] = [NSString stringWithFormat:@"bytes %@-%@/%@", @(range.location), @(range.location + range.length - 1), @(response.expectedContentLength)];
    response = [[NSHTTPURLResponse alloc] initWithURL:response.URL
                                           statusCode:response.statusCode
                                          HTTPVersion:@"HTTP/1.1"
                                         headerFields:allHeaderFields];
    
    return response;
}

- (void)save {
    @synchronized (self.writeFileHandle) {
        [self.writeFileHandle synchronizeFile];
        [self.cacheConfiguration save];
    }
}

@end

//
//  VIMediaCacheWorker.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VIMediaCacheWorker.h"
#import "VICacheAction.h"

static NSInteger const kPackageLength = 204800; // 200kb per package

@interface VIMediaCacheWorkerFactory : NSObject

@property (nonatomic, strong) NSMutableDictionary *memoryCacheWorkers;

@end

@implementation VIMediaCacheWorkerFactory

+ (instancetype)shared {
    static VIMediaCacheWorkerFactory *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.memoryCacheWorkers = [NSMutableDictionary dictionary];
    });
    
    return instance;
}

- (VIMediaCacheWorker *)cacheWorkerWithFilePath:(NSString *)filePath {
    VIMediaCacheWorker *cacheWorker = self.memoryCacheWorkers[filePath];
    if (!cacheWorker) {
        cacheWorker = [[VIMediaCacheWorker alloc] initWithCacheFilePath:filePath];
        if (filePath) {
            self.memoryCacheWorkers[filePath] = cacheWorker;
        }
    }
    
    return cacheWorker;
}

@end

static NSString *kMCMediaCacheResponseKey = @"kMCMediaCacheResponseKey";


@interface VIMediaCacheWorker ()

@property (nonatomic, strong) NSFileHandle *readFileHandle;
@property (nonatomic, strong) NSFileHandle *writeFileHandle;
@property (nonatomic, strong, readwrite) NSError *setupError;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) VIMutableCacheConfiguration *internalCacheConfiguration;

@property (nonatomic) long long currentOffset;

@property (nonatomic, strong) NSDate *startWriteDate;
@property (nonatomic) float writeBytes;
@property (nonatomic) BOOL writting;

@end

@implementation VIMediaCacheWorker

- (void)dealloc {
    [_readFileHandle closeFile];
    [_writeFileHandle closeFile];
}

+ (instancetype)inMemoryCacheWorkerWithFilePath:(NSString *)filePath {
    return [[VIMediaCacheWorkerFactory shared] cacheWorkerWithFilePath:filePath];
}

- (instancetype)initWithCacheFilePath:(NSString *)path {
    self = [super init];
    if (self) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        _filePath = path;
        NSError *error;
        NSString *cacheFolder = [path stringByDeletingLastPathComponent];
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
                _internalCacheConfiguration = [VIMutableCacheConfiguration configurationWithFilePath:path];
            }
        }
        
        _setupError = error;
    }
    return self;
}

- (VICacheConfiguration *)cacheConfiguration {
    return [self.internalCacheConfiguration copy];
}

- (void)cacheData:(NSData *)data forRange:(NSRange)range {
    @synchronized(self.writeFileHandle) {
        @try {
            [self.writeFileHandle seekToFileOffset:range.location];
            [self.writeFileHandle writeData:data];
            self.writeBytes += data.length;
            [self.internalCacheConfiguration addCacheFragment:range];
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
            NSData *data = [self.readFileHandle readDataOfLength:range.length]; // 空数据也会返回，所以如果 range 错误，会导致播放失效
            return data;
        } @catch (NSException *exception) {
            NSLog(@"read cached data error %@",exception);
        }
    }
    return nil;
}

- (NSArray<VICacheAction *> *)cachedDataActionsForRange:(NSRange)range {
    NSArray *cachedFragments = [self.internalCacheConfiguration cacheFragments];
    NSMutableArray *actions = [NSMutableArray array];
    
    if (range.location == NSNotFound) {
        return [actions copy];
    }
    NSInteger endOffset = range.location + range.length;
    // Delete header and footer not in range
    [cachedFragments enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange fragmentRange = obj.rangeValue;
        NSRange intersectionRange = NSIntersectionRange(range, fragmentRange);
        if (intersectionRange.length > 0) {
            NSInteger package = intersectionRange.length / kPackageLength;
            for (NSInteger i = 0; i <= package; i++) {
                VICacheAction *action = [VICacheAction new];
                action.actionType = VICacheAtionTypeLocal;
                
                NSInteger offset = i * kPackageLength;
                NSInteger offsetLocation = intersectionRange.location + offset;
                NSInteger maxLocation = intersectionRange.location + intersectionRange.length;
                NSInteger length = (offsetLocation + kPackageLength) > maxLocation ? (maxLocation - offsetLocation) : kPackageLength;
                action.range = NSMakeRange(offsetLocation, length);
                
                [actions addObject:action];
            }
        } else if (fragmentRange.location >= endOffset) {
            *stop = YES;
        }
    }];
    
    if (actions.count == 0) {
        VICacheAction *action = [VICacheAction new];
        action.actionType = VICacheAtionTypeRemote;
        action.range = range;
        [actions addObject:action];
    } else {
        // Add remote fragments
        NSMutableArray *localRemoteActions = [NSMutableArray array];
        [actions enumerateObjectsUsingBlock:^(VICacheAction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSRange actionRange = obj.range;
            if (idx == 0) {
                if (range.location < actionRange.location) {
                    VICacheAction *action = [VICacheAction new];
                    action.actionType = VICacheAtionTypeRemote;
                    action.range = NSMakeRange(range.location, actionRange.location - range.location);
                    [localRemoteActions addObject:action];
                }
                [localRemoteActions addObject:obj];
            } else {
                VICacheAction *lastAction = [localRemoteActions lastObject];
                NSInteger lastOffset = lastAction.range.location + lastAction.range.length;
                if (actionRange.location > lastOffset) {
                    VICacheAction *action = [VICacheAction new];
                    action.actionType = VICacheAtionTypeRemote;
                    action.range = NSMakeRange(lastOffset, actionRange.location - lastOffset);
                    [localRemoteActions addObject:action];
                }
                [localRemoteActions addObject:obj];
            }
            
            if (idx == actions.count - 1) {
                NSInteger localEndOffset = actionRange.location + actionRange.length;
                if (endOffset > localEndOffset) {
                    VICacheAction *action = [VICacheAction new];
                    action.actionType = VICacheAtionTypeRemote;
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
        [self.internalCacheConfiguration updateResponse:response];
        
        [self.writeFileHandle truncateFileAtOffset:response.expectedContentLength];
        [self.writeFileHandle synchronizeFile];
    }
}

- (NSURLResponse *)cachedResponse {
    return self.internalCacheConfiguration.response;
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
        [self.internalCacheConfiguration save];
    }
}

- (void)startWritting {
    self.writting = YES;
    self.startWriteDate = [NSDate date];
    self.writeBytes = 0;
}

- (void)finishWritting {
    if (self.writting) {
        self.writting = NO;
        NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:self.startWriteDate];
        [self.internalCacheConfiguration addDownloadedBytes:self.writeBytes spent:time];
    }
}

@end

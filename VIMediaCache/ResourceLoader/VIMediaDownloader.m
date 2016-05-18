//
//  VIMediaDownloader.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VIMediaDownloader.h"
#import "VIContentInfo.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "VIURLProtocol.h"
#import "VICacheSessionManager.h"

@interface VIMediaDownloader () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *task;

@property (nonatomic, strong) NSMutableDictionary *taskDelegateDic;

@end

@implementation VIMediaDownloader

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _url = url;
        _taskDelegateDic = [NSMutableDictionary dictionary];
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.protocolClasses = [@[[VIURLProtocol class]] arrayByAddingObjectsFromArray:configuration.protocolClasses];
        NSOperationQueue *queue = [VICacheSessionManager shared].downloadQueue;
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
        self.session = session;
    }
    return self;
}

- (NSURLSessionDataTask *)fetchFileInfoTaskWithCompletion:(void(^)(VIContentInfo *info, NSError *error))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    request.HTTPMethod = @"HEAD";
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            VIContentInfo *info = [VIContentInfo new];
            
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
                NSString *acceptRange = HTTPURLResponse.allHeaderFields[@"Accept-Ranges"];
                info.byteRangeAccessSupported = [acceptRange isEqualToString:@"bytes"];
            }
            info.contentLength = response.expectedContentLength;
            NSString *mimeType = response.MIMEType;
            CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
            info.contentType = CFBridgingRelease(contentType);
            completion(info, nil);
        } else {
            completion(nil, error);
        }
    }];
    
    return task;
}


- (NSURLSessionDataTask *)downloadTaskWithDelegate:(id<MediaDownloaderDelegate>)delegate
                                        fromOffset:(unsigned long long)fromOffset
                                            length:(unsigned long long)length {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    NSString *range = [NSString stringWithFormat:@"Bytes=%lld-%lld", fromOffset, fromOffset + length - 1];
    [request setValue:range forHTTPHeaderField:@"Range"];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
    self.taskDelegateDic[task] = delegate;
    
    return task;
}

- (void)cancelTask:(NSURLSessionTask *)task {
    if (task.state != NSURLSessionTaskStateCanceling || task.state != NSURLSessionTaskStateCompleted) {
        [task cancel];
    }
    [self.taskDelegateDic removeObjectForKey:task];
}

- (void)cancelAllTasks {
    [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
        [dataTasks makeObjectsPerformSelector:@selector(cancel)];
    }];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSString *mimeType = response.MIMEType;
    // Only download video/audio data
    // TODO: support HLS, RTMP
    if ([mimeType rangeOfString:@"video/"].location != NSNotFound ||
        [mimeType rangeOfString:@"audio/"].location != NSNotFound) {
        completionHandler(NSURLSessionResponseAllow);
    } else {
        completionHandler(NSURLSessionResponseCancel);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    id<MediaDownloaderDelegate> delegate = self.taskDelegateDic[dataTask];
    [delegate mediaDownloader:self didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    id<MediaDownloaderDelegate> delegate = self.taskDelegateDic[task];
    [delegate mediaDownloader:self didFinishedWithError:error];
    [self.taskDelegateDic removeObjectForKey:task];
}

@end

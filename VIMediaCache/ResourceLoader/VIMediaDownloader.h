//
//  VIMediaDownloader.h
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MediaDownloaderDelegate;
@class VIContentInfo;

@interface VIMediaDownloader : NSObject

- (instancetype)initWithURL:(NSURL *)url;
@property (nonatomic, strong, readonly) NSURL *url;

- (NSURLSessionDataTask *)fetchFileInfoTaskWithCompletion:(void(^)(VIContentInfo *info, NSError *error))completion;

- (NSURLSessionDataTask *)downloadTaskWithDelegate:(id<MediaDownloaderDelegate>)delegate
                                        fromOffset:(unsigned long long)fromOffset
                                            length:(NSInteger)length;
- (void)cancelTask:(NSURLSessionTask *)task;
- (void)invalidateAndCancel;

@end

@protocol MediaDownloaderDelegate <NSObject>

- (void)mediaDownloader:(VIMediaDownloader *)downloader didReceiveData:(NSData *)data;
- (void)mediaDownloader:(VIMediaDownloader *)downloader didFinishedWithError:(NSError *)error;

@end

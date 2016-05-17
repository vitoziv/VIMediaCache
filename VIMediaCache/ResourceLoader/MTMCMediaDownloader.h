//
//  MTMCMediaDownloader.h
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MediaDownloaderDelegate;
@class MTMCContentInfo;

@interface MTMCMediaDownloader : NSObject

- (instancetype)initWithURL:(NSURL *)url;
@property (nonatomic, strong, readonly) NSURL *url;

- (NSURLSessionDataTask *)fetchFileInfoTaskWithCompletion:(void(^)(MTMCContentInfo *info, NSError *error))completion;

- (NSURLSessionDataTask *)downloadTaskWithDelegate:(id<MediaDownloaderDelegate>)delegate
                                        fromOffset:(unsigned long long)fromOffset
                                            length:(unsigned long long)length;
- (void)cancelTask:(NSURLSessionTask *)task;
- (void)cancelAllTasks;

@end

@protocol MediaDownloaderDelegate <NSObject>

- (void)mediaDownloader:(MTMCMediaDownloader *)downloader didReceiveData:(NSData *)data;
- (void)mediaDownloader:(MTMCMediaDownloader *)downloader didFinishedWithError:(NSError *)error;

@end

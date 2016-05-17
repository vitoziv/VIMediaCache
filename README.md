# VIMediaCache

Cache media file while play media using AVPlayerr.

VIMediaCache use AVAssetResourceLoader to control AVPlayer download media data, then manage cache data using NSURLProtocol.

### CocoaPods

`pod 'VIMediaCache'`

### Usage

    NSURL *url = [NSURL URLWithString:@"https://mvvideo5.meitudata.com/571090934cea5517.mp4"];
    
    MTMCResourceLoaderManager *resourceLoaderManager = [MTMCResourceLoaderManager new];
    self.resourceLoaderManager = resourceLoaderManager;
    
    AVPlayerItem *playerItem = [resourceLoaderManager playerItemWithURL:url];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];

### Contact

vvitozhang@gmail.com

### License

MIT

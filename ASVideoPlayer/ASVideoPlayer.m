
#import "ASVideoPlayer.h"
@import CoreMedia;

@implementation ASVideoPlayer

// - (void)seekToTime:(CMTime)time;
// NSTimeInterval currentTime;
// - play
// - pause
// status
// potientally prepareToPlayAsset: withKeys:_requestedKeys];
// setPlayerItem: onLoaded
// Add periodic time observer **very important**
// Sync time with audio

// the callback is invoked on an arbitrary queue
// the callback is not called when loading is cancelled
- (void)loadAsset:(AVURLAsset *)asset completionHandler:(nullable AssetLoadingCompletionHandler)completionHandler {
    
    if (!asset.URL.isFileURL) {
        if (completionHandler) {
            completionHandler(NO, ASVideoPlayerLoadingErrorInvalidURL, nil);
        }
        return;
    }
    
    _asset = asset;
    _status = ASVideoPlayerStatusLoading;
    _currentTime = CMTimeMake(0, 1);
    
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        
        NSError *loadingError;
        AVKeyValueStatus status = [asset statusOfValueForKey:@"tracks" error:&loadingError];
        switch (status) {
            case AVKeyValueStatusLoaded:
                [self loadPlayer:completionHandler];
                break;
            case AVKeyValueStatusFailed: {
                _asset = nil;
                _status = ASVideoPlayerStatusNoItem;
                if (completionHandler) {
                    BOOL isDirectory = NO;
                    if (![[NSFileManager defaultManager] fileExistsAtPath:asset.URL.path isDirectory:&isDirectory] || isDirectory) {
                        completionHandler(NO, ASVideoPlayerLoadingErrorAssetNotFound, loadingError);
                    } else {
                        completionHandler(NO, ASVideoPlayerLoadingErrorUnknown, loadingError);
                    }
                }
            }
                break;
            case AVKeyValueStatusCancelled:
            default: break;
        }
    }];
}

- (void)loadPlayer:(nullable AssetLoadingCompletionHandler)completionHandler {
    AVAssetTrack *video = [[_asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    AVAssetTrack *audio = [[_asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    
    if (video) {
        NSError *error;
        _reader = [AVAssetReader assetReaderWithAsset:_asset error:&error];
        _reader.timeRange = CMTimeRangeMake(CMTimeMake(0, _asset.duration.timescale), _asset.duration);
        
        if (error) {
            _asset = nil;
            _videoOutput = nil;
            _audioOutput = nil;
            _reader = nil;
            _status = ASVideoPlayerStatusNoItem;
            if (completionHandler) {
                completionHandler(NO, ASVideoPlayerLoadingErrorUnknown, error);
            }
        } else {
            
            // TODO: settings for iOS simulator
            NSDictionary *settings = @{
                                       (NSString *) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
                                       (NSString *) kCVPixelBufferWidthKey : @(video.naturalSize.width),
                                       (NSString *) kCVPixelBufferHeightKey : @(video.naturalSize.height)
                                       };
            
            _videoOutput = [AVAssetReaderTrackOutput
                            assetReaderTrackOutputWithTrack:video
                            outputSettings:settings];
            [_reader addOutput:_videoOutput];
            
            if (audio) {
                _audioOutput = [AVAssetReaderTrackOutput
                                assetReaderTrackOutputWithTrack:audio
                                outputSettings:nil];
            }
            
            _status = ASVideoPlayerStatusReadyToPlay;
            if (completionHandler) {
                completionHandler(YES, ASVideoPlayerLoadingErrorNone, nil);
            }
        }
    }
}

- (ASVideoPlayerPlaybackError)play {
    if (_status == ASVideoPlayerStatusNoItem || _status == ASVideoPlayerStatusLoading) {
        return ASVideoPlayerPlaybackErrorNotReady;
    } else if (!_playerLayer) {
        return ASVideoPlayerPlaybackErrorNoLayer;
    } else if (_status == ASVideoPlayerStatusPaused) {
        [self loadPlayer:nil];
    }
    
    CMTimebaseRef timebase;
    CMClockRef clock;
    CMAudioClockCreate(kCFAllocatorDefault, &clock);
    CMTimebaseCreateWithMasterClock(
                                    kCFAllocatorDefault,
                                    clock,
                                    &timebase);
    _playerLayer.controlTimebase = timebase;
    CMTimebaseGetTime(timebase);
    CMTimebaseSetTime(_playerLayer.controlTimebase, _currentTime);
    // TODO: Extract rate setting
    CMTimebaseSetRate(_playerLayer.controlTimebase, 1);
    
    _status = ASVideoPlayerStatusPlaying;
    [_reader startReading];
    
    [_playerLayer
     requestMediaDataWhenReadyOnQueue:[ASVideoPlayer playerQueue]
     usingBlock:^{
        while (_playerLayer.isReadyForMoreMediaData) {
            if (_reader.status == AVAssetReaderStatusReading) {
                CMSampleBufferRef buffer = [_videoOutput copyNextSampleBuffer];
                if (!buffer) {
                    return;
                }
                [_playerLayer enqueueSampleBuffer:buffer];
                CMSampleBufferInvalidate(buffer);
                CFRelease(buffer);
            } else {
                return;
            }
        }
    }];
    
    return ASVideoPlayerPlaybackErrorNone;
}

- (void)pause {
    if (_status != ASVideoPlayerStatusPlaying) {
        return;
    }
    
    _status = ASVideoPlayerStatusPaused;
    _currentTime = CMTimebaseGetTime(_playerLayer.controlTimebase);
    [_reader cancelReading];
    [_playerLayer stopRequestingMediaData];
}

+ (dispatch_queue_t)playerQueue {
    static dispatch_once_t onceToken;
    static dispatch_queue_t queue;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.asvideoplayer.queue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

@end

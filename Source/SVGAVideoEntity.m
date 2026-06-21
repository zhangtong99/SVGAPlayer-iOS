//
//  SVGAVideoEntity.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 16/6/17.
//  Copyright © 2016年 UED Center. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <math.h>
#import "SVGAVideoEntity.h"
#import "SVGABezierPath.h"
#import "SVGAVideoSpriteEntity.h"
#import "SVGAAudioEntity.h"
#import "Svga.pbobjc.h"

#define MP3_MAGIC_NUMBER "ID3"

@interface SVGAVideoEntity ()

@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) int FPS;
@property (nonatomic, assign) int frames;
@property (nonatomic, copy) NSDictionary<NSString *, UIImage *> *images;
@property (nonatomic, copy) NSDictionary<NSString *, NSData *> *imagesData;
@property (nonatomic, copy) NSDictionary<NSString *, NSData *> *audiosData;
@property (nonatomic, copy) NSArray<SVGAVideoSpriteEntity *> *sprites;
@property (nonatomic, copy) NSArray<SVGAAudioEntity *> *audios;
@property (nonatomic, copy) NSString *cacheDir;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *scaledImages;

+ (CGFloat)quantizedRenderScale:(CGFloat)renderScale;

@end

@implementation SVGAVideoEntity

static NSCache *videoCache;
static NSMapTable * weakCache;
static dispatch_semaphore_t videoSemaphore;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        videoCache = [[NSCache alloc] init];
        weakCache = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory
        valueOptions:NSPointerFunctionsWeakMemory
            capacity:64];
        videoSemaphore = dispatch_semaphore_create(1);
    });
}

- (UIImage *)imageForKey:(NSString *)key renderScale:(CGFloat)renderScale {
    if (key.length == 0) return nil;
    UIImage *originImage = self.images[key];
    if (originImage == nil) return nil;

    CGFloat safeRenderScale = [self.class quantizedRenderScale:renderScale];
    if (safeRenderScale >= 0.999) {
        return originImage;
    }

    CGFloat pixelWidth = originImage.size.width * originImage.scale;
    CGFloat pixelHeight = originImage.size.height * originImage.scale;
    CGFloat maxPixelSize = MAX(pixelWidth, pixelHeight) * safeRenderScale;
    if (maxPixelSize < 1) {
        return originImage;
    }

    NSString *cacheKey = [NSString stringWithFormat:@"%@_%.3f", key, safeRenderScale];
    UIImage *cachedImage = [self.scaledImages objectForKey:cacheKey];
    if (cachedImage != nil) {
        return cachedImage;
    }

    UIImage *scaledImage = [self downsampledImageForKey:key fallbackImage:originImage maxPixelSize:maxPixelSize];
    if (scaledImage == nil) {
        scaledImage = originImage;
    }
    NSUInteger cost = 0;
    if (scaledImage.CGImage != nil) {
        cost = CGImageGetBytesPerRow(scaledImage.CGImage) * CGImageGetHeight(scaledImage.CGImage);
    }
    [self.scaledImages setObject:scaledImage forKey:cacheKey cost:cost];
    return scaledImage;
}

- (UIImage *)downsampledImageForKey:(NSString *)key fallbackImage:(UIImage *)image maxPixelSize:(CGFloat)maxPixelSize {
    if (image == nil || maxPixelSize <= 0) return nil;
    NSData *imageData = self.imagesData[key];
    if (imageData == nil) return nil;

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (source == NULL) return nil;

    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (__bridge NSString *)kCGImageSourceShouldCacheImmediately: @YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(ceil(maxPixelSize))
    };
    CGImageRef cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    if (cgImage == NULL) return nil;

    UIImage *downsampledImage = [UIImage imageWithCGImage:cgImage scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cgImage);
    return downsampledImage;
}

- (void)clearScaledImageCache {
    [self.scaledImages removeAllObjects];
}

- (NSCache<NSString *,UIImage *> *)scaledImages {
    if (_scaledImages == nil) {
        _scaledImages = [[NSCache alloc] init];
        _scaledImages.countLimit = 24;
        _scaledImages.totalCostLimit = 8 * 1024 * 1024;
    }
    return _scaledImages;
}

+ (CGFloat)quantizedRenderScale:(CGFloat)renderScale {
    CGFloat safeRenderScale = renderScale > 0 ? renderScale : 1.0;
    if (safeRenderScale >= 0.999) return 1.0;
    safeRenderScale = MAX(safeRenderScale, 0.1);
    CGFloat bucket = 0.125;
    return MAX(ceil(safeRenderScale / bucket) * bucket, bucket);
}

- (instancetype)initWithJSONObject:(NSDictionary *)JSONObject cacheDir:(NSString *)cacheDir {
    self = [super init];
    if (self) {
        _videoSize = CGSizeMake(100, 100);
        _FPS = 20;
        _images = @{};
        _imagesData = @{};
        _cacheDir = cacheDir;
        [self resetMovieWithJSONObject:JSONObject];
    }
    return self;
}

- (void)resetMovieWithJSONObject:(NSDictionary *)JSONObject {
    if ([JSONObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary *movieObject = JSONObject[@"movie"];
        if ([movieObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *viewBox = movieObject[@"viewBox"];
            if ([viewBox isKindOfClass:[NSDictionary class]]) {
                NSNumber *width = viewBox[@"width"];
                NSNumber *height = viewBox[@"height"];
                if ([width isKindOfClass:[NSNumber class]] && [height isKindOfClass:[NSNumber class]]) {
                    _videoSize = CGSizeMake(width.floatValue, height.floatValue);
                }
            }
            NSNumber *FPS = movieObject[@"fps"];
            if ([FPS isKindOfClass:[NSNumber class]]) {
                _FPS = [FPS intValue];
            }
            NSNumber *frames = movieObject[@"frames"];
            if ([frames isKindOfClass:[NSNumber class]]) {
                _frames = [frames intValue];
            }
        }
    }
}

- (void)resetImagesWithJSONObject:(NSDictionary *)JSONObject {
    if ([JSONObject isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary<NSString *, UIImage *> *images = [[NSMutableDictionary alloc] init];
        NSMutableDictionary<NSString *, NSData *> *imagesData = [[NSMutableDictionary alloc] init];
        NSDictionary<NSString *, NSString *> *JSONImages = JSONObject[@"images"];
        if ([JSONImages isKindOfClass:[NSDictionary class]]) {
            [JSONImages enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
                if ([obj isKindOfClass:[NSString class]]) {
                    NSString *filePath = [self.cacheDir stringByAppendingFormat:@"/%@.png", obj];
//                    NSData *imageData = [NSData dataWithContentsOfFile:filePath];
                    NSData *imageData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:NULL];
                    if (imageData != nil) {
                        UIImage *image = [[UIImage alloc] initWithData:imageData scale:2.0];
                        if (image != nil) {
                            NSString *imageKey = [key stringByDeletingPathExtension];
                            [images setObject:image forKey:imageKey];
                            [imagesData setObject:imageData forKey:imageKey];
                        }
                    }
                }
            }];
        }
        self.images = images;
        self.imagesData = imagesData;
    }
}

- (void)resetSpritesWithJSONObject:(NSDictionary *)JSONObject {
    if ([JSONObject isKindOfClass:[NSDictionary class]]) {
        NSMutableArray<SVGAVideoSpriteEntity *> *sprites = [[NSMutableArray alloc] init];
        NSArray<NSDictionary *> *JSONSprites = JSONObject[@"sprites"];
        if ([JSONSprites isKindOfClass:[NSArray class]]) {
            [JSONSprites enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj isKindOfClass:[NSDictionary class]]) {
                    SVGAVideoSpriteEntity *spriteItem = [[SVGAVideoSpriteEntity alloc] initWithJSONObject:obj];
                    [sprites addObject:spriteItem];
                }
            }];
        }
        self.sprites = sprites;
    }
}

- (instancetype)initWithProtoObject:(SVGAProtoMovieEntity *)protoObject cacheDir:(NSString *)cacheDir {
    self = [super init];
    if (self) {
        _videoSize = CGSizeMake(100, 100);
        _FPS = 20;
        _images = @{};
        _imagesData = @{};
        _cacheDir = cacheDir;
        [self resetMovieWithProtoObject:protoObject];
    }
    return self;
}

- (void)resetMovieWithProtoObject:(SVGAProtoMovieEntity *)protoObject {
    if (protoObject.hasParams) {
        self.videoSize = CGSizeMake((CGFloat)protoObject.params.viewBoxWidth, (CGFloat)protoObject.params.viewBoxHeight);
        self.FPS = (int)protoObject.params.fps;
        self.frames = (int)protoObject.params.frames;
    }
}

+ (BOOL)isMP3Data:(NSData *)data {
    BOOL result = NO;
    if (!strncmp([data bytes], MP3_MAGIC_NUMBER, strlen(MP3_MAGIC_NUMBER))) {
        result = YES;
    }
    return result;
}

- (void)resetImagesWithProtoObject:(SVGAProtoMovieEntity *)protoObject {
    NSMutableDictionary<NSString *, UIImage *> *images = [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString *, NSData *> *imagesData = [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString *, NSData *> *audiosData = [[NSMutableDictionary alloc] init];
    NSDictionary *protoImages = [protoObject.images copy];
    for (NSString *key in protoImages) {
        NSString *fileName = [[NSString alloc] initWithData:protoImages[key] encoding:NSUTF8StringEncoding];
        if (fileName != nil) {
            NSString *filePath = [self.cacheDir stringByAppendingFormat:@"/%@.png", fileName];
            if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                filePath = [self.cacheDir stringByAppendingFormat:@"/%@", fileName];
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
//                NSData *imageData = [NSData dataWithContentsOfFile:filePath];
                NSData *imageData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:NULL];
                if (imageData != nil) {
                    UIImage *image = [[UIImage alloc] initWithData:imageData scale:2.0];
                    if (image != nil) {
                        [images setObject:image forKey:key];
                        [imagesData setObject:imageData forKey:key];
                    }
                }
            }
        }
        else if ([protoImages[key] isKindOfClass:[NSData class]]) {
            if ([SVGAVideoEntity isMP3Data:protoImages[key]]) {
                // mp3
                [audiosData setObject:protoImages[key] forKey:key];
            } else {
                UIImage *image = [[UIImage alloc] initWithData:protoImages[key] scale:2.0];
                if (image != nil) {
                    [images setObject:image forKey:key];
                    [imagesData setObject:protoImages[key] forKey:key];
                }
            }
        }
    }
    self.images = images;
    self.imagesData = imagesData;
    self.audiosData = audiosData;
}

- (void)resetSpritesWithProtoObject:(SVGAProtoMovieEntity *)protoObject {
    NSMutableArray<SVGAVideoSpriteEntity *> *sprites = [[NSMutableArray alloc] init];
    NSArray *protoSprites = [protoObject.spritesArray copy];
    [protoSprites enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[SVGAProtoSpriteEntity class]]) {
            SVGAVideoSpriteEntity *spriteItem = [[SVGAVideoSpriteEntity alloc] initWithProtoObject:obj];
            [sprites addObject:spriteItem];
        }
    }];
    self.sprites = sprites;
}

- (void)resetAudiosWithProtoObject:(SVGAProtoMovieEntity *)protoObject {
    NSMutableArray<SVGAAudioEntity *> *audios = [[NSMutableArray alloc] init];
    NSArray *protoAudios = [protoObject.audiosArray copy];
    [protoAudios enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[SVGAProtoAudioEntity class]]) {
            SVGAAudioEntity *audioItem = [[SVGAAudioEntity alloc] initWithProtoObject:obj];
            [audios addObject:audioItem];
        }
    }];
    self.audios = audios;
}

+ (SVGAVideoEntity *)readCache:(NSString *)cacheKey {
    dispatch_semaphore_wait(videoSemaphore, DISPATCH_TIME_FOREVER);
    SVGAVideoEntity * object = [videoCache objectForKey:cacheKey];
    if (!object) {
        object = [weakCache objectForKey:cacheKey];
    }
    dispatch_semaphore_signal(videoSemaphore);

    return  object;
}

+ (void)setMemoryCacheCountLimit:(NSUInteger)countLimit totalCostLimit:(NSUInteger)totalCostLimit {
    dispatch_semaphore_wait(videoSemaphore, DISPATCH_TIME_FOREVER);
    videoCache.countLimit = countLimit;
    videoCache.totalCostLimit = totalCostLimit;
    dispatch_semaphore_signal(videoSemaphore);
}

+ (void)clearMemoryCache {
    dispatch_semaphore_wait(videoSemaphore, DISPATCH_TIME_FOREVER);
    [videoCache removeAllObjects];
    [weakCache removeAllObjects];
    dispatch_semaphore_signal(videoSemaphore);
}

- (void)saveCache:(NSString *)cacheKey {
    dispatch_semaphore_wait(videoSemaphore, DISPATCH_TIME_FOREVER);
    NSUInteger cost = 1;
    for (UIImage *image in self.images.allValues) {
        CGSize imageSize = image.size;
        CGFloat imageScale = image.scale > 0 ? image.scale : UIScreen.mainScreen.scale;
        NSUInteger imageCost = (NSUInteger)(imageSize.width * imageScale * imageSize.height * imageScale * 4.0);
        cost += imageCost;
    }
    for (NSData *audioData in self.audiosData.allValues) {
        cost += audioData.length;
    }
    for (NSData *imageData in self.imagesData.allValues) {
        cost += imageData.length;
    }
    [videoCache setObject:self forKey:cacheKey cost:cost];
    dispatch_semaphore_signal(videoSemaphore);
}

- (void)saveWeakCache:(NSString *)cacheKey {
    dispatch_semaphore_wait(videoSemaphore, DISPATCH_TIME_FOREVER);
    [weakCache setObject:self forKey:cacheKey];
    dispatch_semaphore_signal(videoSemaphore);
}

@end

@interface SVGAVideoSpriteEntity()

@property (nonatomic, copy) NSString *imageKey;
@property (nonatomic, copy) NSArray<SVGAVideoSpriteFrameEntity *> *frames;
@property (nonatomic, copy) NSString *matteKey;

@end

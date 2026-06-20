//
//  SVGAVideoSpriteFrameEntity.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/2/20.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import "SVGAVideoSpriteFrameEntity.h"
#import "SVGAVectorLayer.h"
#import "SVGABezierPath.h"
#import "Svga.pbobjc.h"

@interface SVGAVideoSpriteFrameEntity ()

//@property (nonatomic, strong) SVGAVideoSpriteFrameEntity *previousFrame;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign) CGAffineTransform transform;
@property (nonatomic, assign) CGRect layout;
@property (nonatomic, assign) CGFloat nx;
@property (nonatomic, assign) CGFloat ny;
@property (nonatomic, copy) NSString *clipPath;
@property (nonatomic, strong) CALayer *maskLayer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CALayer *> *scaledMaskLayers;
@property (nonatomic, copy) NSArray *shapes;

@end

@implementation SVGAVideoSpriteFrameEntity

- (instancetype)initWithJSONObject:(NSDictionary *)JSONObject {
    self = [super init];
    if (self) {
        _alpha = 0.0;
        _layout = CGRectZero;
        _transform = CGAffineTransformMake(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
        if ([JSONObject isKindOfClass:[NSDictionary class]]) {
            NSNumber *alpha = JSONObject[@"alpha"];
            if ([alpha isKindOfClass:[NSNumber class]]) {
                _alpha = [alpha floatValue];
            }
            NSDictionary *layout = JSONObject[@"layout"];
            if ([layout isKindOfClass:[NSDictionary class]]) {
                NSNumber *x = layout[@"x"];
                NSNumber *y = layout[@"y"];
                NSNumber *width = layout[@"width"];
                NSNumber *height = layout[@"height"];
                if ([x isKindOfClass:[NSNumber class]] && [y isKindOfClass:[NSNumber class]] && [width isKindOfClass:[NSNumber class]] && [height isKindOfClass:[NSNumber class]]) {
                    _layout = CGRectMake(x.floatValue, y.floatValue, width.floatValue, height.floatValue);
                }
            }
            NSDictionary *transform = JSONObject[@"transform"];
            if ([transform isKindOfClass:[NSDictionary class]]) {
                NSNumber *a = transform[@"a"];
                NSNumber *b = transform[@"b"];
                NSNumber *c = transform[@"c"];
                NSNumber *d = transform[@"d"];
                NSNumber *tx = transform[@"tx"];
                NSNumber *ty = transform[@"ty"];
                if ([a isKindOfClass:[NSNumber class]] && [b isKindOfClass:[NSNumber class]] && [c isKindOfClass:[NSNumber class]] && [d isKindOfClass:[NSNumber class]] && [tx isKindOfClass:[NSNumber class]] && [ty isKindOfClass:[NSNumber class]]) {
                    _transform = CGAffineTransformMake(a.floatValue, b.floatValue, c.floatValue, d.floatValue, tx.floatValue, ty.floatValue);
                }
            }
            NSString *clipPath = JSONObject[@"clipPath"];
            if ([clipPath isKindOfClass:[NSString class]]) {
                self.clipPath = clipPath;
            }
            NSArray *shapes = JSONObject[@"shapes"];
            if ([shapes isKindOfClass:[NSArray class]]) {
                _shapes = shapes;
            }
        }
        CGFloat llx = _transform.a * _layout.origin.x + _transform.c * _layout.origin.y + _transform.tx;
        CGFloat lrx = _transform.a * (_layout.origin.x + _layout.size.width) + _transform.c * _layout.origin.y + _transform.tx;
        CGFloat lbx = _transform.a * _layout.origin.x + _transform.c * (_layout.origin.y + _layout.size.height) + _transform.tx;
        CGFloat rbx = _transform.a * (_layout.origin.x + _layout.size.width) + _transform.c * (_layout.origin.y + _layout.size.height) + _transform.tx;
        CGFloat lly = _transform.b * _layout.origin.x + _transform.d * _layout.origin.y + _transform.ty;
        CGFloat lry = _transform.b * (_layout.origin.x + _layout.size.width) + _transform.d * _layout.origin.y + _transform.ty;
        CGFloat lby = _transform.b * _layout.origin.x + _transform.d * (_layout.origin.y + _layout.size.height) + _transform.ty;
        CGFloat rby = _transform.b * (_layout.origin.x + _layout.size.width) + _transform.d * (_layout.origin.y + _layout.size.height) + _transform.ty;
        _nx = MIN(MIN(lbx,  rbx), MIN(llx, lrx));
        _ny = MIN(MIN(lby,  rby), MIN(lly, lry));
    }
    return self;
}

- (instancetype)initWithProtoObject:(SVGAProtoFrameEntity *)protoObject {
    self = [super init];
    if (self) {
        _alpha = 0.0;
        _layout = CGRectZero;
        _transform = CGAffineTransformMake(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);
        if ([protoObject isKindOfClass:[SVGAProtoFrameEntity class]]) {
            _alpha = protoObject.alpha;
            if (protoObject.hasLayout) {
                _layout = CGRectMake((CGFloat)protoObject.layout.x,
                                     (CGFloat)protoObject.layout.y,
                                     (CGFloat)protoObject.layout.width,
                                     (CGFloat)protoObject.layout.height);
            }
            if (protoObject.hasTransform) {
                _transform = CGAffineTransformMake((CGFloat)protoObject.transform.a,
                                                   (CGFloat)protoObject.transform.b,
                                                   (CGFloat)protoObject.transform.c,
                                                   (CGFloat)protoObject.transform.d,
                                                   (CGFloat)protoObject.transform.tx,
                                                   (CGFloat)protoObject.transform.ty);
            }
            if ([protoObject.clipPath isKindOfClass:[NSString class]] && protoObject.clipPath.length > 0) {
                self.clipPath = protoObject.clipPath;
            }
            if ([protoObject.shapesArray isKindOfClass:[NSArray class]]) {
                _shapes = [protoObject.shapesArray copy];
            }
        }
        CGFloat llx = _transform.a * _layout.origin.x + _transform.c * _layout.origin.y + _transform.tx;
        CGFloat lrx = _transform.a * (_layout.origin.x + _layout.size.width) + _transform.c * _layout.origin.y + _transform.tx;
        CGFloat lbx = _transform.a * _layout.origin.x + _transform.c * (_layout.origin.y + _layout.size.height) + _transform.tx;
        CGFloat rbx = _transform.a * (_layout.origin.x + _layout.size.width) + _transform.c * (_layout.origin.y + _layout.size.height) + _transform.tx;
        CGFloat lly = _transform.b * _layout.origin.x + _transform.d * _layout.origin.y + _transform.ty;
        CGFloat lry = _transform.b * (_layout.origin.x + _layout.size.width) + _transform.d * _layout.origin.y + _transform.ty;
        CGFloat lby = _transform.b * _layout.origin.x + _transform.d * (_layout.origin.y + _layout.size.height) + _transform.ty;
        CGFloat rby = _transform.b * (_layout.origin.x + _layout.size.width) + _transform.d * (_layout.origin.y + _layout.size.height) + _transform.ty;
        _nx = MIN(MIN(lbx,  rbx), MIN(llx, lrx));
        _ny = MIN(MIN(lby,  rby), MIN(lly, lry));
    }
    return self;
}

- (CALayer *)maskLayer {
    if (_maskLayer == nil && self.clipPath != nil) {
        SVGABezierPath *bezierPath = [[SVGABezierPath alloc] init];
        [bezierPath setValues:self.clipPath];
        _maskLayer = [bezierPath createLayer];
    }
    return _maskLayer;
}

- (CGRect)layoutForRenderScale:(CGFloat)renderScale {
    if (renderScale <= 0 || renderScale == 1) return self.layout;
    return CGRectMake(self.layout.origin.x * renderScale,
                      self.layout.origin.y * renderScale,
                      self.layout.size.width * renderScale,
                      self.layout.size.height * renderScale);
}

- (CGAffineTransform)transformForRenderScale:(CGFloat)renderScale {
    if (renderScale <= 0 || renderScale == 1) return self.transform;
    CGAffineTransform transform = self.transform;
    transform.tx *= renderScale;
    transform.ty *= renderScale;
    return transform;
}

- (CGFloat)nxForRenderScale:(CGFloat)renderScale {
    if (renderScale <= 0 || renderScale == 1) return self.nx;
    return self.nx * renderScale;
}

- (CGFloat)nyForRenderScale:(CGFloat)renderScale {
    if (renderScale <= 0 || renderScale == 1) return self.ny;
    return self.ny * renderScale;
}

- (CALayer *)maskLayerForRenderScale:(CGFloat)renderScale {
    if (self.clipPath == nil) return nil;
    if (renderScale <= 0 || renderScale == 1) return self.maskLayer;

    NSString *cacheKey = [NSString stringWithFormat:@"%.4f", renderScale];
    CALayer *cachedLayer = self.scaledMaskLayers[cacheKey];
    if (cachedLayer != nil) return cachedLayer;

    SVGABezierPath *bezierPath = [[SVGABezierPath alloc] init];
    bezierPath.renderScale = renderScale;
    [bezierPath setValues:self.clipPath];
    CALayer *maskLayer = [bezierPath createLayer];
    if (maskLayer != nil) {
        self.scaledMaskLayers[cacheKey] = maskLayer;
    }
    return maskLayer;
}

- (NSMutableDictionary<NSString *,CALayer *> *)scaledMaskLayers {
    if (_scaledMaskLayers == nil) {
        _scaledMaskLayers = [NSMutableDictionary dictionary];
    }
    return _scaledMaskLayers;
}

- (void)dealloc {
    if (_maskLayer) {
        [_maskLayer removeFromSuperlayer];
        _maskLayer = nil;
    }
    [_scaledMaskLayers removeAllObjects];
    _clipPath = nil;
    _shapes = nil;
}

@end

//
//  SVGAVectorLayer.h
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/2/20.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@class SVGAVideoSpriteFrameEntity;

@interface SVGAVectorLayer : CALayer

- (instancetype)initWithFrames:(NSArray<SVGAVideoSpriteFrameEntity *> *)frames;
- (instancetype)initWithFrames:(NSArray<SVGAVideoSpriteFrameEntity *> *)frames renderScale:(CGFloat)renderScale;

- (void)stepToFrame:(NSInteger)frame;

@end

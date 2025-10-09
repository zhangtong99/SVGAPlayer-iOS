//
//  SVGABitmapLayer.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 2017/2/20.
//  Copyright © 2017年 UED Center. All rights reserved.
//

#import "SVGABitmapLayer.h"
#import "SVGABezierPath.h"
#import "SVGAVideoSpriteFrameEntity.h"

@interface SVGABitmapLayer ()

@property (nonatomic, strong) NSArray<SVGAVideoSpriteFrameEntity *> *frames;
@property (nonatomic, assign) NSInteger drawedFrame;

@end

@implementation SVGABitmapLayer

- (instancetype)initWithFrames:(NSArray *)frames {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor].CGColor;
        self.masksToBounds = NO;
        // 此处代码会导致替换的图片不能达到理想的视觉大小
//        self.contentsGravity = kCAGravityResizeAspect;
        _frames = frames;
        [self stepToFrame:0];
    }
    return self;
}

- (void)stepToFrame:(NSInteger)frame {
}

@end

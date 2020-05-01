//
//  JotImageViewContainer.m
//  Pods
//
//  Created by Steve Stencil on 4/29/20.
//

#import "JotImageViewContainer.h"
#import "Masonry.h"

#define DEGREES_TO_RADIANS(x) (M_PI * (x) / 180.0)
#define RADIANS_TO_DEGREES(x) (x * (180 / M_PI))

@interface JotImageViewContainer ()

@property (nonatomic) CGFloat aspectRatio;

@end

@implementation JotImageViewContainer

+ (instancetype) imageViewContainerWithImage:(UIImage*)image {
    JotImageViewContainer *container = [JotImageViewContainer new];
    [container addImageViewWithImage:image];
    container.backgroundColor = [UIColor clearColor];
    container.scale = 1.0f;
    container.aspectRatio = image.size.width / image.size.height;
    return container;
}

- (void) addImageViewWithImage:(UIImage*)image {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    [self addSubview:imageView];
    _imageView = imageView;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.userInteractionEnabled = NO;
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.mas_width);
        make.height.equalTo(self.mas_height);
        make.center.equalTo(self);
    }];
}

- (void) layoutSubviews {
    [super layoutSubviews];
}

- (void) resizeWithSize:(CGSize)size andCenter:(CGPoint)center {
    CGFloat widthPercentage = MAX(0.15f, floorf((size.width / CGRectGetWidth(self.superview.frame)) * 100) / 100);
//    CGFloat heightPercentage = MAX(0.15f, floorf((size.height / CGRectGetHeight(self.superview.frame)) * 100) / 100);
    [self mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.superview.mas_width).multipliedBy(MAX(0.15f, widthPercentage));
        make.height.equalTo(self.mas_width).dividedBy(self.aspectRatio);
        make.centerX.equalTo(self.superview.mas_right).multipliedBy(center.x / CGRectGetWidth(self.superview.frame));
        make.centerY.equalTo(self.superview.mas_bottom).multipliedBy(center.y / CGRectGetHeight(self.superview.frame));
    }];
}

- (void) moveViewToCenter:(CGPoint)center {
    CGRect currentFrame = self.frame;
    CGFloat widthPercentage = floorf((CGRectGetWidth(currentFrame) / CGRectGetWidth(self.superview.frame)) * 100) / 100;
//    CGFloat heightPercentage = floorf((CGRectGetHeight(currentFrame) / CGRectGetHeight(self.superview.frame)) * 100) / 100;
    [self mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.superview.mas_width).multipliedBy(MAX(0.15f, widthPercentage));
        make.height.equalTo(self.mas_width).dividedBy(self.aspectRatio);
        make.centerX.equalTo(self.superview.mas_right).multipliedBy(center.x / CGRectGetWidth(self.superview.frame));
        make.centerY.equalTo(self.superview.mas_bottom).multipliedBy(center.y / CGRectGetHeight(self.superview.frame));
    }];
}

#pragma mark - Setters & Getters

- (void)setTransform:(CGAffineTransform)transform {
    CGFloat angle = RADIANS_TO_DEGREES(atan2f(transform.b, transform.a));
    if (angle >= -5 && angle <= 5) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(0));
    } else if (angle >= 85 && angle <= 95) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(90));
    } else if (angle >= -95 && angle <= -85) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-90));
    } else if ((angle >= 175 && angle <= 185)) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(180));
    } else if (angle >= -185 && angle <= -175) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-180));
    }
    self.imageView.transform = transform;
}

- (CGAffineTransform)transform {
    return self.imageView.transform;
}

- (void) setSelected:(BOOL)selected {
    if (!selected) {
        self.imageView.layer.borderWidth = 0.0;
    } else {
        self.imageView.layer.borderWidth = 2.0;
        self.imageView.layer.borderColor = [[UIColor yellowColor] CGColor];
    }
}

@end

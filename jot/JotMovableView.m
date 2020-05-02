//
//  JotImageViewContainer.m
//  Pods
//
//  Created by Steve Stencil on 4/29/20.
//

#import "JotMovableView.h"
#import "Masonry.h"

@interface JotMovableView ()

@property (nonatomic) CGFloat aspectRatio;
@property (strong, nonatomic) NSMutableArray<NSDictionary*> *editHistory;
@property (weak, nonatomic, readonly) UIImageView *imageView;

@end

@implementation JotMovableView

+ (instancetype) imageViewContainerWithImage:(UIImage*)image {
    JotMovableView *container = [JotMovableView new];
    [container addImageViewWithImage:image];
    container.backgroundColor = [UIColor clearColor];
    container.aspectRatio = image.size.width / image.size.height;
    return container;
}

- (void) addImageViewWithImage:(UIImage*)image {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    [self addSubview:imageView];
    _imageView = imageView;
    _type = JotMovableViewContainerTypeImage;
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

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    self.center = self.superview.center;
}

#pragma mark - Undo

- (void) captureUndoObject {
    NSDictionary *object = @{
        @"size": [NSValue valueWithCGSize:self.frame.size],
        @"center": [NSValue valueWithCGPoint:self.center],
        @"transform": [NSValue valueWithCGAffineTransform:self.transform]
    };
    [self.editHistory addObject:object];
}

- (instancetype) undo {
    NSDictionary *lastCapture = [self.editHistory lastObject];
    if (!lastCapture) {
        [self removeFromSuperview];
        return nil;
    }
    CGSize size = [lastCapture[@"size"] CGSizeValue];
    CGPoint center = [lastCapture[@"center"] CGPointValue];
    CGAffineTransform transform = [lastCapture[@"transform"] CGAffineTransformValue];
    
    CGFloat widthPercentage = MAX(0.15f, floorf((size.width / CGRectGetWidth(self.superview.frame)) * 100) / 100);
    [self mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.superview.mas_width).multipliedBy(MAX(0.15f, widthPercentage));
        make.height.equalTo(self.mas_width).dividedBy(self.aspectRatio);
        make.centerX.equalTo(self.superview.mas_right).multipliedBy(center.x / CGRectGetWidth(self.superview.frame));
        make.centerY.equalTo(self.superview.mas_bottom).multipliedBy(center.y / CGRectGetHeight(self.superview.frame));
    }];
    self.transform = transform;
    [self.editHistory removeLastObject];
    return self;
}

#pragma mark - Moving, Resizing and Rotation

- (void) resizeWithSize:(CGSize)size {
    CGFloat widthPercentage = MAX(0.15f, floorf((size.width / CGRectGetWidth(self.superview.frame)) * 100) / 100);
    [self mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.superview.mas_width).multipliedBy(MAX(0.15f, widthPercentage));
        make.height.equalTo(self.mas_width).dividedBy(self.aspectRatio);
        make.centerX.equalTo(self.superview.mas_right).multipliedBy(self.center.x / CGRectGetWidth(self.superview.frame));
        make.centerY.equalTo(self.superview.mas_bottom).multipliedBy(self.center.y / CGRectGetHeight(self.superview.frame));
    }];
}

- (void)resizeWithScale:(CGFloat)scale {
    CGSize newSize = CGSizeMake(self.superview.frame.size.width, self.superview.frame.size.width / self.aspectRatio);
    if (newSize.height > self.superview.frame.size.height) {
        newSize.height = self.superview.frame.size.height;
        newSize.width = self.superview.frame.size.height * self.aspectRatio;
    }
    [self resizeWithSize:CGSizeMake(newSize.width * scale, newSize.height * scale)];
}

- (void) moveViewToCenter:(CGPoint)center {
    CGFloat widthPercentage = floorf((CGRectGetWidth(self.frame) / CGRectGetWidth(self.superview.frame)) * 100) / 100;
    [self mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.superview.mas_width).multipliedBy(MAX(0.15f, widthPercentage));
        make.height.equalTo(self.mas_width).dividedBy(self.aspectRatio);
        make.centerX.equalTo(self.superview.mas_right).multipliedBy(center.x / CGRectGetWidth(self.superview.frame));
        make.centerY.equalTo(self.superview.mas_bottom).multipliedBy(center.y / CGRectGetHeight(self.superview.frame));
    }];
}

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

#pragma mark - Setters & Getters

- (void) setSelected:(BOOL)selected {
    if (!selected) {
        self.imageView.layer.borderWidth = 0.0;
    } else {
        self.imageView.layer.borderWidth = 2.0;
        self.imageView.layer.borderColor = [[UIColor yellowColor] CGColor];
    }
}

- (NSMutableArray<NSDictionary *> *)editHistory {
    if (!_editHistory) {
        _editHistory = [NSMutableArray new];
    }
    return _editHistory;
}

- (UIImage *)image {
    return self.imageView.image;
}

@end

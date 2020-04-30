//
//  JotImageView.m
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import "JotImageView.h"
#import "Masonry.h"

#define DEGREES_TO_RADIANS(x) (M_PI * (x) / 180.0)
#define RADIANS_TO_DEGREES(x) (x * (180 / M_PI))

@interface JotImageView ()

@property (nonatomic, strong) NSMutableArray<JotImageViewContainer*> *imageViews;
@property (nonatomic, strong) JotImageViewContainer *movingImageView;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) CGPoint referenceOffset;
@property (nonatomic, assign) CGAffineTransform referenceRotateTransform;
@property (nonatomic, assign) CGAffineTransform currentRotateTransform;
@property (nonatomic, strong) UIPinchGestureRecognizer *activePinchRecognizer;
@property (nonatomic, strong) UIRotationGestureRecognizer *activeRotationRecognizer;

@end

@implementation JotImageView

- (instancetype)init {
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = YES;
        _scale = 1.f;
        self.referenceOffset = CGPointZero;
        _referenceRotateTransform = CGAffineTransformIdentity;
        _currentRotateTransform = CGAffineTransformIdentity;
    }
    return self;
}

- (NSInteger)imageCount {
    return self.imageViews.count;
}

- (void)cancelEditing {
    self.movingImageView = nil;
}

#pragma mark - Undo

- (void)clearImages
{
    self.scale = 1.f;
    while (self.imageViews.count) {
        JotImageViewContainer *imageView = [self.imageViews firstObject];
        [imageView removeFromSuperview];
        [self.imageViews removeObject:imageView];
    }
}

#pragma mark - Properties

- (CGSize) sizeForImage:(UIImage*)image withScale:(CGFloat)scale {
    CGFloat aspectRatio = image.size.width / image.size.height;
    CGSize imageViewSize = CGSizeMake(self.frame.size.width, self.frame.size.width / aspectRatio);
    if (imageViewSize.height > self.frame.size.height) {
        imageViewSize.height = self.frame.size.height;
        imageViewSize.width = self.frame.size.height * aspectRatio;
    }
    return CGSizeMake(imageViewSize.width * scale, imageViewSize.height * scale);
}

- (void) rotateView:(JotImageViewContainer*)view withTransform:(CGAffineTransform)transform {
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
    view.transform = transform;
}

- (void) resizeView:(JotImageViewContainer*)view withSize:(CGSize)size andCenter:(CGPoint)center {
    CGFloat widthPercentage = MAX(0.15f, floorf((size.width / CGRectGetWidth(self.frame)) * 100) / 100);
    CGFloat heightPercentage = MAX(0.15f, floorf((size.height / CGRectGetHeight(self.frame)) * 100) / 100);
    [view mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.mas_width).multipliedBy(MAX(0.15f, widthPercentage));
        make.height.equalTo(self.mas_height).multipliedBy(MAX(0.15f, heightPercentage));
        make.centerX.equalTo(self.mas_right).multipliedBy(center.x / CGRectGetWidth(self.frame));
        make.centerY.equalTo(self.mas_bottom).multipliedBy(center.y / CGRectGetHeight(self.frame));
    }];
}

- (void) moveView:(JotImageViewContainer*)view toCenter:(CGPoint)center {
    CGRect currentFrame = view.frame;
    CGFloat widthPercentage = floorf((CGRectGetWidth(currentFrame) / CGRectGetWidth(self.frame)) * 100) / 100;
    CGFloat heightPercentage = floorf((CGRectGetHeight(currentFrame) / CGRectGetHeight(self.frame)) * 100) / 100;
    [self.movingImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.mas_width).multipliedBy(MAX(0.15f, widthPercentage));
        make.height.equalTo(self.mas_height).multipliedBy(MAX(0.15f, heightPercentage));
        make.centerX.equalTo(self.mas_right).multipliedBy(center.x / CGRectGetWidth(self.frame));
        make.centerY.equalTo(self.mas_bottom).multipliedBy(center.y / CGRectGetHeight(self.frame));
    }];
}

- (CGRect) frameForViewWithSize:(CGSize)size withCenterPoint:(CGPoint)center {
    return CGRectMake(center.x - (size.width / 2), center.y - (size.height / 2), size.width, size.height);
}

- (void)addImageView:(UIImage *)image {
    JotImageViewContainer *containerView = [JotImageViewContainer imageViewContainerWithImage:image];
    [self addSubview:containerView];
    CGSize imageViewSize = [self sizeForImage:image withScale:1.0];
    CGRect frame = [self frameForViewWithSize:imageViewSize withCenterPoint:self.center];
    [self resizeView:containerView withSize:frame.size andCenter:self.center];
    [self.imageViews addObject:containerView];
}

#pragma mark - Gestures

- (JotImageViewContainer*) imageViewAtPoint:(CGPoint)point {
    JotImageViewContainer *view = (JotImageViewContainer*)[self hitTest:point withEvent:nil];
    if ([self.imageViews containsObject:view]) {
        return view;
    }
    return nil;
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            JotImageViewContainer *view = [self imageViewAtPoint:point];
            self.movingImageView = view;
            if (!self.movingImageView) {
                return;
            }
            // add 5 points to make the view move slightly to indicate it's selected
            self.referenceOffset = CGPointMake(view.center.x - point.x + 5.0,
                                               view.center.y - point.y - 5.0);
            CGPoint newCenter = CGPointMake(point.x + self.referenceOffset.x,
                                            point.y + self.referenceOffset.y);
            [self moveView:self.movingImageView toCenter:newCenter];
            
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didBeginMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:view];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (!self.movingImageView) {
                return;
            }
            CGPoint point = [recognizer locationInView:self];
            CGPoint newCenter = CGPointMake(point.x + self.referenceOffset.x,
                                            point.y + self.referenceOffset.y);
            [self moveView:self.movingImageView toCenter:newCenter];
            
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didMoveImageView:)]) {
                [self.delegate jotImageView:self didMoveImageView:self.movingImageView];
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.referenceOffset = CGPointZero;
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didEndMovingImageView:)]) {
                [self.delegate jotImageView:self didEndMovingImageView:self.movingImageView];
            }
            break;
        }
            
        default:
            break;
    }
}

- (void) handlePinchGesture:(UIPinchGestureRecognizer*)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            self.movingImageView = [self imageViewAtPoint:point];
            if (!self.movingImageView) {
                return;
            }
            self.activePinchRecognizer = (UIPinchGestureRecognizer *)recognizer;
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didBeginMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:self.movingImageView];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (!self.movingImageView) {
                return;
            }
            CGFloat scale = self.activePinchRecognizer.scale * self.scale;
            CGSize size = [self sizeForImage:self.movingImageView.imageView.image withScale:scale];
            [self resizeView:self.movingImageView withSize:size andCenter:self.movingImageView.center];
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didMoveImageView:)]) {
                [self.delegate jotImageView:self didMoveImageView:self.movingImageView];
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.scale *= [(UIPinchGestureRecognizer *)recognizer scale];
            self.activePinchRecognizer = nil;
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didEndMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:self.movingImageView];
            }
            break;
        }
            
        default:
            break;
    }
}

- (void) handleRotateGesture:(UIRotationGestureRecognizer*)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            self.movingImageView = [self imageViewAtPoint:point];
            if (!self.movingImageView) {
                return;
            }
            if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
                self.currentRotateTransform = self.referenceRotateTransform;
                self.activeRotationRecognizer = (UIRotationGestureRecognizer *)recognizer;
            } else {
                self.activePinchRecognizer = (UIPinchGestureRecognizer *)recognizer;
            }
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didBeginMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:self.movingImageView];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (!self.movingImageView) {
                return;
            }
            CGAffineTransform currentTransform = self.referenceRotateTransform;
            self.currentRotateTransform = CGAffineTransformRotate(self.referenceRotateTransform, recognizer.rotation);
            currentTransform = CGAffineTransformRotate(currentTransform, self.activeRotationRecognizer.rotation);
            [self rotateView:self.movingImageView withTransform:currentTransform];
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didMoveImageView:)]) {
                [self.delegate jotImageView:self didMoveImageView:self.movingImageView];
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.referenceRotateTransform = CGAffineTransformRotate(self.referenceRotateTransform, recognizer.rotation);
            self.currentRotateTransform = self.referenceRotateTransform;
            self.activeRotationRecognizer = nil;
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didEndMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:self.movingImageView];
            }
            break;
        }
            
        default:
            break;
    }
}

//+ (CGAffineTransform)applyRecognizer:(UIGestureRecognizer *)recognizer toTransform:(CGAffineTransform)transform
//{
//    if (!recognizer
//        || !([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]
//             || [recognizer isKindOfClass:[UIPinchGestureRecognizer class]])) {
//        return transform;
//    }
//
//    if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
//
//        return CGAffineTransformRotate(transform, [(UIRotationGestureRecognizer *)recognizer rotation]);
//    }
//
//    CGFloat scale = [(UIPinchGestureRecognizer *)recognizer scale];
//    return CGAffineTransformScale(transform, scale, scale);
//}

#pragma mark - Image Render

- (UIImage*) renderImage {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - Setters & Getters

- (NSMutableArray<JotImageViewContainer *> *)imageViews {
    if (!_imageViews) {
        _imageViews = [NSMutableArray new];
    }
    return _imageViews;
}

- (BOOL)isMovingView {
    return !!self.movingImageView;
}

- (void)setMovingImageView:(JotImageViewContainer *)movingImageView {
    [_movingImageView setSelected:NO];
    _movingImageView = movingImageView;
    [_movingImageView setSelected:YES];
}

@end

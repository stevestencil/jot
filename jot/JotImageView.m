//
//  JotImageView.m
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import "JotImageView.h"
#import "Masonry.h"

@interface JotImageView ()

@property (nonatomic, strong) NSMutableArray<UIImageView*> *imageViews;
@property (nonatomic, strong) UIImageView *movingImageView;
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
        UIImageView *imageView = [self.imageViews firstObject];
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
- (void)addImageView:(UIImage *)image {
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.userInteractionEnabled = YES;
    [self addSubview:imageView];
    CGSize imageViewSize = [self sizeForImage:image withScale:1.0];
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.mas_width).multipliedBy(imageViewSize.width / CGRectGetWidth(self.frame));
        make.height.equalTo(self.mas_height).multipliedBy(imageViewSize.height / CGRectGetHeight(self.frame));
        make.centerX.equalTo(self.mas_right).multipliedBy(0.5);
        make.centerY.equalTo(self.mas_bottom).multipliedBy(0.5);
    }];
    [self.imageViews addObject:imageView];
}

#pragma mark - Gestures

- (UIImageView*) imageViewAtPoint:(CGPoint)point {
    UIImageView *view = (UIImageView*)[self hitTest:point withEvent:nil];
    if ([self.imageViews containsObject:view]) {
        return view;
    }
    return nil;
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            UIImageView *view = [self imageViewAtPoint:point];
            self.movingImageView = view;
            // add 5 points to make the view move slightly to indicate it's selected
            self.referenceOffset = CGPointMake(view.center.x - point.x + 5.0,
                                               view.center.y - point.y - 5.0);
            CGPoint newCenter = CGPointMake(point.x + self.referenceOffset.x,
                                            point.y + self.referenceOffset.y);
            [self.movingImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(self.mas_width).multipliedBy(CGRectGetWidth(self.movingImageView.frame) / CGRectGetWidth(self.frame));
                make.height.equalTo(self.mas_height).multipliedBy(CGRectGetHeight(self.movingImageView.frame) / CGRectGetHeight(self.frame));
                make.centerX.equalTo(self.mas_right).multipliedBy(newCenter.x / CGRectGetWidth(self.frame));
                make.centerY.equalTo(self.mas_bottom).multipliedBy(newCenter.y / CGRectGetHeight(self.frame));
            }];
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didBeginMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:view];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            CGPoint point = [recognizer locationInView:self];
            CGPoint newCenter = CGPointMake(point.x + self.referenceOffset.x,
                                            point.y + self.referenceOffset.y);
            [self.movingImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(self.mas_width).multipliedBy(CGRectGetWidth(self.movingImageView.frame) / CGRectGetWidth(self.frame));
                make.height.equalTo(self.mas_height).multipliedBy(CGRectGetHeight(self.movingImageView.frame) / CGRectGetHeight(self.frame));
                make.centerX.equalTo(self.mas_right).multipliedBy(newCenter.x / CGRectGetWidth(self.frame));
                make.centerY.equalTo(self.mas_bottom).multipliedBy(newCenter.y / CGRectGetHeight(self.frame));
            }];
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

- (void)handlePinchOrRotateGesture:(UIGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            self.movingImageView = [self imageViewAtPoint:point];
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
            
            CGAffineTransform currentTransform = self.referenceRotateTransform;
            
            if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
                self.currentRotateTransform = [self.class applyRecognizer:recognizer toTransform:self.referenceRotateTransform];
            }
                        
//            currentTransform = [self.class applyRecognizer:self.activePinchRecognizer toTransform:currentTransform];
            currentTransform = [self.class applyRecognizer:self.activeRotationRecognizer toTransform:currentTransform];
//            self.movingImageView.transform = currentTransform;

            [self.movingImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
                CGFloat scale = self.activePinchRecognizer.scale * self.scale;
                CGSize size = [self sizeForImage:self.movingImageView.image withScale:scale];
                make.width.equalTo(self.mas_width).multipliedBy(size.width / CGRectGetWidth(self.frame));
                make.height.equalTo(self.mas_height).multipliedBy(size.height / CGRectGetHeight(self.frame));
                make.centerX.equalTo(self.mas_right).multipliedBy(CGRectGetMidX(self.movingImageView.frame) / CGRectGetWidth(self.frame));
                make.centerY.equalTo(self.mas_bottom).multipliedBy(CGRectGetMidY(self.movingImageView.frame) / CGRectGetHeight(self.frame));
            }];
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didMoveImageView:)]) {
                [self.delegate jotImageView:self didMoveImageView:self.movingImageView];
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
                
                self.referenceRotateTransform = [self.class applyRecognizer:recognizer toTransform:self.referenceRotateTransform];
                self.currentRotateTransform = self.referenceRotateTransform;
                self.activeRotationRecognizer = nil;
                
            } else if ([recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
                
                self.scale *= [(UIPinchGestureRecognizer *)recognizer scale];
                self.activePinchRecognizer = nil;
            }
            
            if (self.movingImageView && [self.delegate respondsToSelector:@selector(jotImageView:didEndMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:self.movingImageView];
            }
            break;
        }
            
        default:
            break;
    }
}

+ (CGAffineTransform)applyRecognizer:(UIGestureRecognizer *)recognizer toTransform:(CGAffineTransform)transform
{
    if (!recognizer
        || !([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]
             || [recognizer isKindOfClass:[UIPinchGestureRecognizer class]])) {
        return transform;
    }
    
    if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
        
        return CGAffineTransformRotate(transform, [(UIRotationGestureRecognizer *)recognizer rotation]);
    }
    
    CGFloat scale = [(UIPinchGestureRecognizer *)recognizer scale];
    return CGAffineTransformScale(transform, scale, scale);
}

#pragma mark - Image Render

- (UIImage*) renderImage {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - Setters & Getters

- (NSMutableArray<UIImageView *> *)imageViews {
    if (!_imageViews) {
        _imageViews = [NSMutableArray new];
    }
    return _imageViews;
}

- (BOOL)isMovingView {
    return !!self.movingImageView;
}

- (void)setMovingImageView:(UIImageView *)movingImageView {
    _movingImageView.layer.borderWidth = 0.0;
    _movingImageView = movingImageView;
    _movingImageView.layer.borderWidth = 2.0;
    _movingImageView.layer.borderColor = [[UIColor yellowColor] CGColor];
}

@end

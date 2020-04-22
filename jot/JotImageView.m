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
@property (nonatomic, assign) CGPoint referenceCenter;
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
        self.referenceCenter = CGPointZero;
        _referenceRotateTransform = CGAffineTransformIdentity;
        _currentRotateTransform = CGAffineTransformIdentity;
//        self.userInteractionEnabled = NO;
    }
    return self;
}

#pragma mark - Layout Subviews

//- (void)layoutSubviews
//{
//    [super layoutSubviews];
//
//    if (CGPointEqualToPoint(self.referenceCenter, CGPointZero)) {
//        self.imageView.center = CGPointMake(CGRectGetMidX(self.bounds),
//                                            CGRectGetMidY(self.bounds));
//    }
//}

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

- (void)addImageView:(UIImage *)image {
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.userInteractionEnabled = YES;
    [self addSubview:imageView];
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
        make.center.equalTo(self);
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

- (void)handlePanGesture:(UIGestureRecognizer *)recognizer
{
    if (![recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return;
    }
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:recognizer.view];
            UIImageView *view = [self imageViewAtPoint:point];
            self.movingImageView = view;
            self.referenceCenter = view.center;
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            CGPoint panTranslation = [(UIPanGestureRecognizer *)recognizer translationInView:self];
            self.movingImageView.center = CGPointMake(self.referenceCenter.x + panTranslation.x,
                                                      self.referenceCenter.y + panTranslation.y);;
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.referenceCenter = self.movingImageView.center;
            self.movingImageView = nil;
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
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            
            CGAffineTransform currentTransform = self.referenceRotateTransform;
            
            if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
                self.currentRotateTransform = [self.class applyRecognizer:recognizer toTransform:self.referenceRotateTransform];
            }
            
            currentTransform = [self.class applyRecognizer:self.activePinchRecognizer toTransform:currentTransform];
            currentTransform = [self.class applyRecognizer:self.activeRotationRecognizer toTransform:currentTransform];
            
            self.movingImageView.transform = currentTransform;
            
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.movingImageView = nil;
            if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
                
                self.referenceRotateTransform = [self.class applyRecognizer:recognizer toTransform:self.referenceRotateTransform];
                self.currentRotateTransform = self.referenceRotateTransform;
                self.activeRotationRecognizer = nil;
                
            } else if ([recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
                
                self.scale *= [(UIPinchGestureRecognizer *)recognizer scale];
                self.activePinchRecognizer = nil;
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

@end

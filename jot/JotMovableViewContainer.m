//
//  JotImageView.m
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import "JotMovableViewContainer.h"
#import "Masonry.h"

#define DEGREES_TO_RADIANS(x) (M_PI * (x) / 180.0)
#define RADIANS_TO_DEGREES(x) (x * (180 / M_PI))

@interface JotMovableViewContainer ()

@property (nonatomic, strong) NSMutableArray<JotImageViewContainer*> *movableView;
@property (nonatomic, strong) JotImageViewContainer *movingView;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) CGPoint referenceOffset;
@property (nonatomic, assign) CGAffineTransform referenceRotateTransform;
@property (nonatomic, assign) CGAffineTransform currentRotateTransform;
@property (nonatomic, strong) UIPinchGestureRecognizer *activePinchRecognizer;
@property (nonatomic, strong) UIRotationGestureRecognizer *activeRotationRecognizer;
@property (nonatomic, strong) NSMutableArray<JotImageViewContainer*> *viewsLastEdited;

@end

@implementation JotMovableViewContainer

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
    return self.movableView.count;
}

- (void)cancelEditing {
    self.movingView = nil;
}

#pragma mark - Undo

- (void)clearImages
{
    self.scale = 1.f;
    while (self.movableView.count) {
        JotImageViewContainer *imageView = [self.movableView firstObject];
        [imageView removeFromSuperview];
        [self.movableView removeObject:imageView];
    }
    [UIView transitionWithView:self duration:0.2f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self setNeedsDisplay];
                    }
                    completion:nil];
}

- (void) undo {
    JotImageViewContainer *lastEdited = [self.viewsLastEdited lastObject];
    [lastEdited undo];
    [self.viewsLastEdited removeLastObject];
    [UIView transitionWithView:self duration:0.2f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self setNeedsDisplay];
                    }
                    completion:nil];
}

- (void) captureUndoSnapshot {
    if (self.movingView) {
        [self.movingView captureUndoObject];
        [self.viewsLastEdited addObject:self.movingView];
        if ([self.delegate respondsToSelector:@selector(jotImageViewDidCaptureUndoSnapshot:)]) {
            [self.delegate jotImageViewDidCaptureUndoSnapshot:self];
        }
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

- (CGRect) frameForViewWithSize:(CGSize)size withCenterPoint:(CGPoint)center {
    return CGRectMake(center.x - (size.width / 2), center.y - (size.height / 2), size.width, size.height);
}

- (void)addImageView:(UIImage *)image {
    JotImageViewContainer *containerView = [JotImageViewContainer imageViewContainerWithImage:image];
    [self addSubview:containerView];
    CGSize imageViewSize = [self sizeForImage:image withScale:1.0];
    CGRect frame = [self frameForViewWithSize:imageViewSize withCenterPoint:self.center];
    [containerView resizeWithSize:frame.size];
    [self.movableView addObject:containerView];
    [self.viewsLastEdited addObject:containerView];
    self.movingView = containerView;
    if ([self.delegate respondsToSelector:@selector(jotImageViewDidCaptureUndoSnapshot:)]) {
        [self.delegate jotImageViewDidCaptureUndoSnapshot:self];
    }
}

#pragma mark - Gestures

- (JotImageViewContainer*) imageViewAtPoint:(CGPoint)point {
    JotImageViewContainer *view = (JotImageViewContainer*)[self hitTest:point withEvent:nil];
    if ([self.movableView containsObject:view]) {
        return view;
    }
    return nil;
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            JotImageViewContainer *view = [self imageViewAtPoint:point];
            self.movingView = view;
            if (!self.movingView) {
                return;
            }
            [self captureUndoSnapshot];
            // add 5 points to make the view move slightly to indicate it's selected
            self.referenceOffset = CGPointMake(view.center.x - point.x + 5.0,
                                               view.center.y - point.y - 5.0);
            CGPoint newCenter = CGPointMake(point.x + self.referenceOffset.x,
                                            point.y + self.referenceOffset.y);
            [self.movingView moveViewToCenter:newCenter];
            
            if (self.movingView && [self.delegate respondsToSelector:@selector(jotImageView:didBeginMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:view];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (!self.movingView) {
                return;
            }
            CGPoint point = [recognizer locationInView:self];
            CGPoint newCenter = CGPointMake(point.x + self.referenceOffset.x,
                                            point.y + self.referenceOffset.y);
            [self.movingView moveViewToCenter:newCenter];
            
            if (self.movingView && [self.delegate respondsToSelector:@selector(jotImageView:didMoveImageView:)]) {
                [self.delegate jotImageView:self didMoveImageView:self.movingView];
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.referenceOffset = CGPointZero;
            if (self.movingView && [self.delegate respondsToSelector:@selector(jotImageView:didEndMovingImageView:)]) {
                [self.delegate jotImageView:self didEndMovingImageView:self.movingView];
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
            self.movingView = [self imageViewAtPoint:point];
            if (!self.movingView) {
                return;
            }
            // If rotate is also active we only want to capture a snapshot once
            // Otherwise we'll have to undo twice in order to reverse the pinch
            // and rotate mutations
            if (!self.activeRotationRecognizer) {
                [self captureUndoSnapshot];
            }
            self.activePinchRecognizer = (UIPinchGestureRecognizer *)recognizer;
            if (self.movingView && [self.delegate respondsToSelector:@selector(jotImageView:didBeginMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:self.movingView];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (!self.movingView) {
                return;
            }
            CGFloat scale = self.activePinchRecognizer.scale * self.scale;
            CGSize size = [self sizeForImage:self.movingView.imageView.image withScale:scale];
            [self.movingView resizeWithSize:size];
            if (self.movingView && [self.delegate respondsToSelector:@selector(jotImageView:didMoveImageView:)]) {
                [self.delegate jotImageView:self didMoveImageView:self.movingView];
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.scale *= [(UIPinchGestureRecognizer *)recognizer scale];
            self.activePinchRecognizer = nil;
            if (self.movingView && [self.delegate respondsToSelector:@selector(jotImageView:didEndMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:self.movingView];
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
            self.movingView = [self imageViewAtPoint:point];
            if (!self.movingView) {
                return;
            }
            [self captureUndoSnapshot];
            self.currentRotateTransform = self.referenceRotateTransform;
            self.activeRotationRecognizer = (UIRotationGestureRecognizer *)recognizer;
            if (self.movingView && [self.delegate respondsToSelector:@selector(jotImageView:didBeginMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:self.movingView];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (!self.movingView) {
                return;
            }
            CGAffineTransform currentTransform = self.referenceRotateTransform;
            self.currentRotateTransform = CGAffineTransformRotate(self.referenceRotateTransform, recognizer.rotation);
            currentTransform = CGAffineTransformRotate(currentTransform, self.activeRotationRecognizer.rotation);
            self.movingView.transform = currentTransform;
            if (self.movingView && [self.delegate respondsToSelector:@selector(jotImageView:didMoveImageView:)]) {
                [self.delegate jotImageView:self didMoveImageView:self.movingView];
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.referenceRotateTransform = CGAffineTransformRotate(self.referenceRotateTransform, recognizer.rotation);
            self.currentRotateTransform = self.referenceRotateTransform;
            self.activeRotationRecognizer = nil;
            if (self.movingView && [self.delegate respondsToSelector:@selector(jotImageView:didEndMovingImageView:)]) {
                [self.delegate jotImageView:self didBeginMovingImageView:self.movingView];
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

- (NSMutableArray<JotImageViewContainer *> *)movableView {
    if (!_movableView) {
        _movableView = [NSMutableArray new];
    }
    return _movableView;
}

- (BOOL)isMovingView {
    return !!self.movingView;
}

- (void)setMovingView:(JotImageViewContainer *)movingImageView {
    [_movingView setSelected:NO];
    _movingView = movingImageView;
    [_movingView setSelected:YES];
}

- (NSMutableArray<JotImageViewContainer *> *)viewsLastEdited {
    if (!_viewsLastEdited) {
        _viewsLastEdited = [NSMutableArray new];
    }
    return _viewsLastEdited;
}

@end

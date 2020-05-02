//
//  JotImageView.m
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import "JotMovableViewContainer.h"
#import "JotMovableView.h"
#import "Masonry.h"

@interface JotMovableViewContainer ()

@property (nonatomic, strong) NSMutableArray<JotMovableView*> *movableViews;
@property (nonatomic, weak) JotMovableView *movingView;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) CGPoint referenceOffset;
@property (nonatomic, assign) CGAffineTransform referenceRotateTransform;
@property (nonatomic, assign) CGAffineTransform currentRotateTransform;
@property (nonatomic, strong) UIPinchGestureRecognizer *activePinchRecognizer;
@property (nonatomic, strong) UIRotationGestureRecognizer *activeRotationRecognizer;
@property (nonatomic, strong) NSMutableArray<JotMovableView*> *viewsLastEdited;

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

- (NSInteger)viewCount {
    return self.movableViews.count;
}

- (void)cancelEditing {
    self.movingView = nil;
}

#pragma mark - Undo

- (void)clearAll
{
    self.scale = 1.f;
    while (self.movableViews.count) {
        JotMovableView *imageView = [self.movableViews firstObject];
        [imageView removeFromSuperview];
        [self.movableViews removeObject:imageView];
    }
    [UIView transitionWithView:self duration:0.2f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self setNeedsDisplay];
                    }
                    completion:nil];
}

- (void) undo {
    JotMovableView *lastEdited = [self.viewsLastEdited lastObject];
    if (![lastEdited undo]) {
        [self.movableViews removeObject:lastEdited];
    }
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
        if ([self.delegate respondsToSelector:@selector(jotMovableViewContainerUndoSnapshot:)]) {
            [self.delegate jotMovableViewContainerUndoSnapshot:self];
        }
    }
}

#pragma mark - Properties

- (void)addImageView:(UIImage *)image {
    JotMovableView *containerView = [JotMovableView imageViewContainerWithImage:image];
    [self addSubview:containerView];
    [containerView resizeWithScale:1.0];
    [self.movableViews addObject:containerView];
    [self.viewsLastEdited addObject:containerView];
    self.movingView = containerView;
    if ([self.delegate respondsToSelector:@selector(jotMovableViewContainerUndoSnapshot:)]) {
        [self.delegate jotMovableViewContainerUndoSnapshot:self];
    }
}

#pragma mark - Gestures

- (JotMovableView*) imageViewAtPoint:(CGPoint)point {
    JotMovableView *view = (JotMovableView*)[self hitTest:point withEvent:nil];
    if ([self.movableViews containsObject:view]) {
        return view;
    }
    return nil;
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            JotMovableView *view = [self imageViewAtPoint:point];
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
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.referenceOffset = CGPointZero;
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
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (!self.movingView) {
                return;
            }
            CGFloat scale = self.activePinchRecognizer.scale * self.scale;
            [self.movingView resizeWithScale:scale];
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.scale *= [(UIPinchGestureRecognizer *)recognizer scale];
            self.activePinchRecognizer = nil;
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
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            self.referenceRotateTransform = CGAffineTransformRotate(self.referenceRotateTransform, recognizer.rotation);
            self.currentRotateTransform = self.referenceRotateTransform;
            self.activeRotationRecognizer = nil;
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - Image Render

- (UIImage*) renderImage {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (JotMovableView *movableView in self.movableViews) {
        CGRect frame = movableView.frame;
        CGSize size = frame.size;
        if (movableView.type == JotMovableViewContainerTypeImage) {
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, frame.origin.x, frame.origin.y);
            CGContextTranslateCTM(context, size.width / 2.0f, size.height / 2.0f);
            CGAffineTransform transform = movableView.transform;
            CGFloat angle = atan2f(transform.b, transform.a);
            CGContextRotateCTM(context, angle);
            CGRect drawingRect = CGRectMake(-size.width / 2.0f, -size.height / 2.0f, size.width, size.height);
            [movableView.image drawInRect:drawingRect blendMode:kCGBlendModeNormal alpha:1.0f];
            CGContextRestoreGState(context);
        }
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - Setters & Getters

- (NSMutableArray<JotMovableView *> *)movableViews {
    if (!_movableViews) {
        _movableViews = [NSMutableArray new];
    }
    return _movableViews;
}

- (BOOL)isMovingView {
    return !!self.movingView;
}

- (void)setMovingView:(JotMovableView *)movingImageView {
    [_movingView setSelected:NO];
    _movingView = movingImageView;
    [_movingView setSelected:YES];
}

- (NSMutableArray<JotMovableView *> *)viewsLastEdited {
    if (!_viewsLastEdited) {
        _viewsLastEdited = [NSMutableArray new];
    }
    return _viewsLastEdited;
}

@end

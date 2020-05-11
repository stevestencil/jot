//
//  JotImageView.m
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import "JotMovableViewContainer.h"
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

- (void) moveTextViewsToFront {
    for (JotMovableView *view in self.movableViews) {
        if (view.type == JotMovableViewContainerTypeText) {
            [self bringSubviewToFront:view];
        }
    }
    [self.movableViews removeAllObjects];
    [self.movableViews addObjectsFromArray:self.subviews];
}

- (void)addImageView:(UIImage *)image {
    JotMovableView *containerView = [JotMovableView movableViewWithImage:image];
    [self addSubview:containerView];
    [containerView resizeWithScale:1.0];
    [self.movableViews addObject:containerView];
    [self.viewsLastEdited addObject:containerView];
    self.movingView = containerView;
    [self moveTextViewsToFront];
    if ([self.delegate respondsToSelector:@selector(jotMovableViewContainerUndoSnapshot:)]) {
        [self.delegate jotMovableViewContainerUndoSnapshot:self];
    }
}

- (void) addTextViewWithText:(NSString*)text {
    JotMovableView *containerView = [JotMovableView movableViewWithText:text];
    [self addSubview:containerView];
    [containerView resizeWithScale:1.0];
    [self.movableViews addObject:containerView];
    [self.viewsLastEdited addObject:containerView];
    self.movingView = containerView;
    [self moveTextViewsToFront];
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

- (JotMovableView*)handleTapGesture:(UITapGestureRecognizer *)recognizer {
    for (JotMovableView *view in self.movableViews) {
        [view enableEditing:NO];
    }
    CGPoint point = [recognizer locationInView:self];
    JotMovableView *view = [self imageViewAtPoint:point];
    if (view.type == JotMovableViewContainerTypeText) {
        [view enableEditing:YES];
        return view;
    }
    return nil;
}

- (JotMovableView*) handleMoveGesture:(UIGestureRecognizer*)recognizer withOffset:(CGPoint)offset {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            self.movingView = [self imageViewAtPoint:point] ? : self.movingView;
            if (!self.movingView) {
                return nil;
            }
            [self captureUndoSnapshot];
            self.referenceOffset = CGPointMake(self.movingView.center.x - point.x + offset.x,
                                               self.movingView.center.y - point.y + offset.y);
            CGPoint newCenter = CGPointMake(point.x + self.referenceOffset.x,
                                            point.y + self.referenceOffset.y);
            [self.movingView moveViewToCenter:newCenter];
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (!self.movingView) {
                return nil;
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
    return self.movingView;
}

- (JotMovableView *)handlePanGesture:(UIPanGestureRecognizer *)recognizer {
    return [self handleMoveGesture:recognizer withOffset:CGPointZero];
}

- (JotMovableView *)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer {
    return [self handleMoveGesture:recognizer withOffset:CGPointMake(5.0, -5.0)];
}

- (void) handlePinchGesture:(UIPinchGestureRecognizer*)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            self.movingView = [self imageViewAtPoint:point] ? : self.movingView;
            if (!self.movingView) {
                return;
            }
            self.referenceOffset = CGPointMake(self.movingView.center.x - point.x,
                                               self.movingView.center.y - point.y);
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
            CGPoint point = [recognizer locationInView:self];
            CGPoint newCenter = CGPointMake(point.x + self.referenceOffset.x,
                                            point.y + self.referenceOffset.y);
            CGFloat scale = self.activePinchRecognizer.scale * self.scale;
            [self.movingView resizeWithScale:scale moveToCenter:newCenter];
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
            self.movingView = [self imageViewAtPoint:point] ? : self.movingView;
            if (!self.movingView) {
                return;
            }
            self.referenceOffset = CGPointMake(self.movingView.center.x - point.x,
                                               self.movingView.center.y - point.y);
            [self captureUndoSnapshot];
            self.currentRotateTransform = self.referenceRotateTransform;
            self.activeRotationRecognizer = (UIRotationGestureRecognizer *)recognizer;
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
    return [self renderImageOnImage:nil];
}

- (UIImage *)renderImageOnImage:(UIImage *)image {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 1.0f);
    if (image) {
        [image drawInRect:CGRectMake(0.f, 0.f, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds))];
    }
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (JotMovableView *movableView in self.movableViews) {
        CGRect frame = movableView.frame;
        CGSize size = frame.size;
        if (movableView.type == JotMovableViewContainerTypeImage || movableView.type == JotMovableViewContainerTypeText) {
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, frame.origin.x, frame.origin.y);
            CGContextTranslateCTM(context, size.width / 2.0f, size.height / 2.0f);
            CGAffineTransform transform = movableView.transform;
            CGFloat angle = atan2f(transform.b, transform.a);
            CGContextRotateCTM(context, angle);
            if (movableView.type == JotMovableViewContainerTypeImage) {
                CGRect drawingRect = CGRectMake(-size.width / 2.0f, -size.height / 2.0f, size.width, size.height);
                [movableView.image drawInRect:drawingRect blendMode:kCGBlendModeNormal alpha:1.0f];
            } else if (movableView.type == JotMovableViewContainerTypeText) {
                CGRect drawingRect = CGRectMake(-size.width / 2.0f, -size.height / 2.0f, size.width, size.height);
                NSAttributedString *text = [movableView attributedString];
                [text drawAtPoint:drawingRect.origin];
            }
            CGContextRestoreGState(context);
        }
    }
    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return finalImage;
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

//
//  JotImageView.m
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import "JotMovableViewContainer.h"
#import "Masonry.h"

@interface JotMovableViewContainer () <JotMovableViewDelegate>

@property (nonatomic, strong) NSMutableArray<JotMovableView*> *movableViews;
@property (nonatomic, weak) JotMovableView *movingView;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) CGPoint referenceOffset;
@property (nonatomic, assign) CGAffineTransform referenceRotateTransform;
@property (nonatomic, assign) CGAffineTransform currentRotateTransform;
@property (nonatomic, strong) UIPinchGestureRecognizer *activePinchRecognizer;
@property (nonatomic, strong) UIRotationGestureRecognizer *activeRotationRecognizer;
@property (nonatomic, strong) NSMutableArray<id> *viewsLastEdited;
@property (nonatomic, strong) UIColor *fontColor;

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
        _fontColor = [UIColor blackColor];
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
    NSMutableArray *removedViews = [NSMutableArray new];
    while (self.movableViews.count) {
        JotMovableView *view = [self.movableViews firstObject];
        [view captureUndoObject];
        [removedViews addObject:view];
        [view removeFromSuperview];
        [self.movableViews removeObject:view];
    }
    if (removedViews.count) {
        [self.viewsLastEdited addObject:removedViews];
        [UIView transitionWithView:self duration:0.2f
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            [self setNeedsDisplay];
                        }
                        completion:nil];
        if ([self.delegate respondsToSelector:@selector(jotMovableViewContainerUndoSnapshot:)]) {
            [self.delegate jotMovableViewContainerUndoSnapshot:self];
        }
    }
}

- (void)clearAllWithType:(JotMovableViewContainerType)type {
    self.scale = 1.f;
    NSArray *array = [NSArray arrayWithArray:self.movableViews];
    NSMutableArray *removedViews = [NSMutableArray new];
    for (JotMovableView *view in array) {
        if (view.type == type) {
            [view captureUndoObject];
            [removedViews addObject:view];
            [view removeFromSuperview];
            [self.movableViews removeObject:view];
        }
    }
    if (removedViews.count) {
        [self.viewsLastEdited addObject:removedViews];
        [UIView transitionWithView:self duration:0.2f
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            [self setNeedsDisplay];
                        }
                        completion:nil];
        if ([self.delegate respondsToSelector:@selector(jotMovableViewContainerUndoSnapshot:)]) {
            [self.delegate jotMovableViewContainerUndoSnapshot:self];
        }
    }
}

- (void) undo {
    id object = [self.viewsLastEdited lastObject];
    if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = (NSArray*)object;
        for (JotMovableView *view in array) {
            [self addSubview:view];
            [self.movableViews addObject:view];
            [view undo];
        }
        [self moveTextViewsToFront];
    } else if ([object isKindOfClass:[JotMovableView class]]) {
        JotMovableView *lastEdited = (JotMovableView*)object;
        if ([lastEdited undo]) {
            self.movingView = lastEdited;
        } else {
            [self.movableViews removeObject:lastEdited];
        }
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
    containerView.delegate = self;
    [containerView setFontColor:self.fontColor];
    [self addSubview:containerView];
    [containerView resizeWithScale:1.0];
    [self.movableViews addObject:containerView];
    [self.viewsLastEdited addObject:containerView];
    self.movingView = containerView;
    [self moveTextViewsToFront];
    containerView.isEditing = YES;
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
        view.isEditing = NO;
    }
    CGPoint point = [recognizer locationInView:self];
    JotMovableView *view = [self imageViewAtPoint:point];
    if (view.type == JotMovableViewContainerTypeText) {
        self.movingView = view;
        [self captureUndoSnapshot];
        view.isEditing = YES;
        return view;
    }
    return nil;
}

- (JotMovableView*) handleMoveGesture:(UIGestureRecognizer*)recognizer withOffset:(CGPoint)offset {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            self.movingView = [self imageViewAtPoint:point] ? : self.movingView;
            if (!self.movingView || self.movingView.isEditing) {
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
            if (!self.movingView || self.movingView.isEditing) {
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

- (JotMovableView *) handlePinchGesture:(UIPinchGestureRecognizer*)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            self.movingView = [self imageViewAtPoint:point] ? : self.movingView;
            if (!self.movingView || self.movingView.isEditing) {
                return nil;
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
            if (!self.movingView || self.movingView.isEditing) {
                return nil;
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
    return self.movingView;
}

- (JotMovableView *) handleRotateGesture:(UIRotationGestureRecognizer*)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint point = [recognizer locationInView:self];
            self.movingView = [self imageViewAtPoint:point] ? : self.movingView;
            if (!self.movingView || self.movingView.isEditing) {
                return nil;
            }
            self.referenceOffset = CGPointMake(self.movingView.center.x - point.x,
                                               self.movingView.center.y - point.y);
            [self captureUndoSnapshot];
            self.currentRotateTransform = self.referenceRotateTransform;
            self.activeRotationRecognizer = (UIRotationGestureRecognizer *)recognizer;
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (!self.movingView || self.movingView.isEditing) {
                return nil;
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
    return self.movingView;
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

#pragma mark - JotMovableViewDelegate

- (void)jotMovableView:(JotMovableView *)view didBeginUpdateText:(NSString *)text {
    self.movingView = view;
    [self captureUndoSnapshot];
}

- (void)jotMovableView:(JotMovableView *)view didEndUpdateText:(NSString *)text {

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

- (NSMutableArray<id> *)viewsLastEdited {
    if (!_viewsLastEdited) {
        _viewsLastEdited = [NSMutableArray new];
    }
    return _viewsLastEdited;
}

- (void)setFontColor:(UIColor *)fontColor {
    _fontColor = fontColor;
    [self.movingView setFontColor:fontColor];
}

@end

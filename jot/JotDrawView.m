//
//  JotDrawView.m
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import "JotDrawView.h"
#import "JotTouchPoint.h"
#import "JotTouchBezier.h"
#import "UIImage+Jot.h"

CGFloat const kJotVelocityFilterWeight = 0.9f;
CGFloat const kJotInitialVelocity = 220.f;
CGFloat const kJotRelativeMinStrokeWidth = 0.4f;
CGFloat const kJotSnappedLineTolerance = 15.0f;

@interface JotDrawView ()

@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, strong) NSMutableArray *pathsArray;
@property (nonatomic, strong) NSMutableArray<id> *pathsCounts;
@property (nonatomic, strong) JotTouchBezier *bezierPath;
@property (nonatomic, strong) NSMutableArray<JotTouchPoint*> *pointsArray;
@property (nonatomic, assign) NSUInteger pointsCounter;
@property (nonatomic, assign) CGFloat lastVelocity;
@property (nonatomic, assign) CGFloat lastWidth;
@property (nonatomic, assign) CGFloat initialVelocity;

@end

@implementation JotDrawView

- (instancetype)init
{
    if ((self = [super init])) {
        
        self.backgroundColor = [UIColor clearColor];
                
        _mode = JotDrawViewModeStandard;
        _strokeWidth = 10.f;
        _strokeColor = [UIColor blackColor];
        
        _pathsArray = [NSMutableArray array];
        _pathsCounts = [NSMutableArray new];
        
        _constantStrokeWidth = NO;
        
        _pointsArray = [NSMutableArray array];
        _initialVelocity = kJotInitialVelocity;
        _lastVelocity = _initialVelocity;
        _lastWidth = _strokeWidth;
        
        self.userInteractionEnabled = NO;
    }
    
    return self;
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    self.originalFrame = self.frame;
}

#pragma mark - Undo

- (void) undo {
    id lastObject = [self.pathsCounts lastObject];
    if ([lastObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary *object = [self.pathsCounts lastObject];
        self.pathsArray = [object[@"pathsArray"] mutableCopy];
        self.pathsCounts = [object[@"pathsCounts"] mutableCopy];
    } else if ([lastObject isKindOfClass:[NSNumber class]]) {
        [self.pathsCounts removeLastObject];
        NSInteger lastCount = [[self.pathsCounts lastObject] integerValue];
        while (self.pathsArray.count > lastCount) {
            [self.pathsArray removeLastObject];
        }
    }
    [UIView transitionWithView:self duration:0.2f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self setNeedsDisplay];
                    }
                    completion:nil];
}

- (void)clearDrawing
{
    NSDictionary *object = @{
        @"pathsArray": [NSArray arrayWithArray:self.pathsArray],
        @"pathsCounts": [NSArray arrayWithArray:self.pathsCounts]
    };
    [self.pathsArray removeAllObjects];
    [self.pathsCounts removeAllObjects];
    [self.pathsCounts addObject:object];
    
    self.bezierPath = nil;
    self.pointsCounter = 0;
    [self.pointsArray removeAllObjects];
    self.lastVelocity = self.initialVelocity;
    self.lastWidth = self.strokeWidth;
    
    [UIView transitionWithView:self duration:0.2f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self setNeedsDisplay];
                    }
                    completion:nil];
    
    if ([self.delegate respondsToSelector:@selector(jotDrawViewDidClear:)]) {
        [self.delegate jotDrawViewDidClear:self];
    }
}

#pragma mark - Properties

- (void)setConstantStrokeWidth:(BOOL)constantStrokeWidth
{
    if (_constantStrokeWidth != constantStrokeWidth) {
        _constantStrokeWidth = constantStrokeWidth;
        self.bezierPath = nil;
        [self.pointsArray removeAllObjects];
        self.pointsCounter = 0;
    }
}

#pragma mark - Draw Touches

- (BOOL) isAxis:(CGFloat)axisA closeToAxis:(CGFloat)axisB {
    return axisA >= axisB - kJotSnappedLineTolerance && axisA <= axisB + kJotSnappedLineTolerance;
}

- (BOOL) isPoint:(CGPoint)pointA closeToPoint:(CGPoint)pointB {
    return [self isAxis:pointA.x closeToAxis:pointB.x] && [self isAxis:pointA.y closeToAxis:pointB.y];
}

- (CGFloat) distanceBetweenPointA:(CGPoint)pointA pointB:(CGPoint)pointB {
    CGFloat xDist = (pointB.x - pointA.x);
    CGFloat yDist = (pointB.y - pointA.y);
    return sqrt(xDist * xDist + yDist * yDist);
}

- (CGPoint) translatePointPercentageForPoint:(CGPoint)point {
    return CGPointMake(point.x * CGRectGetWidth(self.frame), point.y * CGRectGetHeight(self.frame));
}

- (CGPoint) convertPointToPercentageOfView:(CGPoint)point {
    return CGPointMake(point.x / CGRectGetWidth(self.frame), point.y / CGRectGetHeight(self.frame));
}

- (void)drawTouchBeganAtPoint:(CGPoint)touchPoint
{
    self.lastVelocity = self.initialVelocity;
    self.lastWidth = self.strokeWidth;
    
    if (self.mode == JotDrawViewModeStraightLines) {
        self.bezierPath = nil;
        CGPoint snappedPoint = CGPointMake(touchPoint.x / CGRectGetWidth(self.frame), touchPoint.y / CGRectGetHeight(self.frame));
        for (id path in self.pathsArray) {
            if ([path isKindOfClass:[JotTouchPoint class]]) {
                JotTouchPoint *point = (JotTouchPoint*)path;
                CGPoint translatedPoint = [self translatePointPercentageForPoint:point.pointPercent];
                if ([self isPoint:touchPoint closeToPoint:translatedPoint]) {
                    snappedPoint = point.pointPercent;
                }
            } else if ([path isKindOfClass:[JotTouchBezier class]]) {
                JotTouchBezier *touchPath = (JotTouchBezier*)path;
                CGPoint translatedStartPoint = [self translatePointPercentageForPoint:touchPath.startPointPercent];
                CGPoint translatedEndPoint = [self translatePointPercentageForPoint:touchPath.endPointPercent];
                if ([self isPoint:touchPoint closeToPoint:translatedStartPoint]) {
                    snappedPoint = touchPath.startPointPercent;
                    break;
                } else if ([self isPoint:touchPoint closeToPoint:translatedEndPoint]) {
                    snappedPoint = touchPath.endPointPercent;
                    break;
                }
            }

        }
        self.bezierPath.startPointPercent = snappedPoint;
        self.bezierPath.endPointPercent = snappedPoint;
        self.bezierPath.startWidthPercent = self.strokeWidth / CGRectGetWidth(self.frame);
        self.bezierPath.endWidthPercent = self.strokeWidth / CGRectGetWidth(self.frame);
        self.bezierPath.straightLine = YES;
        return;
    }

    self.pointsCounter = 0;
    [self.pointsArray removeAllObjects];
    [self.pointsArray addObject:[JotTouchPoint withPoint:touchPoint inFrame:self.frame]];
}

- (void)drawTouchMovedToPoint:(CGPoint)touchPoint
{
    if (self.mode == JotDrawViewModeStraightLines) {
        CGPoint snappedPoint = [self convertPointToPercentageOfView:touchPoint];
        CGPoint convertedStartPoint = [self translatePointPercentageForPoint:self.bezierPath.startPointPercent];
        if ([self isAxis:touchPoint.x closeToAxis:convertedStartPoint.x]) {
            snappedPoint.x = self.bezierPath.startPointPercent.x;
        }
        // if x has been snapped, do not snap y
        if (snappedPoint.x != self.bezierPath.startPointPercent.x && [self isAxis:touchPoint.y closeToAxis:convertedStartPoint.y]) {
            snappedPoint.y = self.bezierPath.startPointPercent.y;
        }
        CGFloat oldDifferenceX = CGFLOAT_MAX;
        CGFloat oldDifferenceY = CGFLOAT_MAX;
        // Iterate through all existing paths to see if the touch is close to any other point's axis
        for (id pathObject in self.pathsArray) {
            if ([pathObject isKindOfClass:[JotTouchBezier class]]) {
                JotTouchBezier *path = (JotTouchBezier*)pathObject;
                CGPoint pathStartPoint = [self translatePointPercentageForPoint:path.startPointPercent];
                CGPoint pathEndPoint = [self translatePointPercentageForPoint:path.endPointPercent];
                // if the path is not a straight line or is our current path, ignore it
                if (path.straightLine && path != self.bezierPath) {
                    if ([self isAxis:touchPoint.x closeToAxis:pathStartPoint.x]) {
                        CGFloat newDifference = fabs(touchPoint.x - pathStartPoint.x);
                        if (newDifference < oldDifferenceX) {
                            oldDifferenceX = newDifference;
                            snappedPoint.x = path.startPointPercent.x;
                        }
                    }
                    if ([self isAxis:touchPoint.x closeToAxis:pathEndPoint.x]) {
                        CGFloat newDifference = fabs(touchPoint.x - pathEndPoint.x);
                        if (newDifference < oldDifferenceX) {
                            oldDifferenceX = newDifference;
                            snappedPoint.x = path.endPointPercent.x;
                        }
                    }
                    if ([self isAxis:touchPoint.y closeToAxis:pathStartPoint.y]) {
                        CGFloat newDifference = fabs(touchPoint.y - pathStartPoint.y);
                        if (newDifference < oldDifferenceY) {
                            oldDifferenceY = newDifference;
                            snappedPoint.y = path.startPointPercent.y;
                        }
                    }
                    if ([self isAxis:touchPoint.y closeToAxis:pathEndPoint.y]) {
                        CGFloat newDifference = fabs(touchPoint.y - pathEndPoint.y);
                        if (newDifference < oldDifferenceY) {
                            oldDifferenceY = newDifference;
                            snappedPoint.y = path.endPointPercent.y;
                        }
                    }
                }
            }

        }
        self.bezierPath.endPointPercent = snappedPoint;
        [self setNeedsDisplay];
        return;
    }
    
    self.pointsCounter += 1;
    [self.pointsArray addObject:[JotTouchPoint withPoint:touchPoint inFrame:self.frame]];
    
    if (self.pointsCounter == 4) {
        
        CGPoint fourthPoint = CGPointMake(([self.pointsArray[2] CGPointValueInFrame:self.frame].x + [self.pointsArray[4] CGPointValueInFrame:self.frame].x)/2.f,
                                          ([self.pointsArray[2] CGPointValueInFrame:self.frame].y + [self.pointsArray[4] CGPointValueInFrame:self.frame].y)/2.f);
        self.pointsArray[3] = [JotTouchPoint withPoint:fourthPoint inFrame:self.frame];
        
        self.bezierPath.startPointPercent = self.pointsArray[0].pointPercent;
        self.bezierPath.endPointPercent = self.pointsArray[3].pointPercent;
        self.bezierPath.controlPoint1Percent = self.pointsArray[1].pointPercent;
        self.bezierPath.controlPoint2Percent = self.pointsArray[2].pointPercent;
        
        if (self.constantStrokeWidth) {
            self.bezierPath.startWidthPercent = self.strokeWidth / CGRectGetWidth(self.frame);
            self.bezierPath.endWidthPercent = self.strokeWidth / CGRectGetWidth(self.frame);
        } else {
            JotTouchPoint *firstPoint = self.pointsArray[0];
            JotTouchPoint *fourthPoint = self.pointsArray[3];
            CGFloat velocity = [firstPoint velocityFromPoint:fourthPoint inFrame:self.frame];
            velocity = (kJotVelocityFilterWeight * velocity) + ((1.f - kJotVelocityFilterWeight) * self.lastVelocity);
            
            CGFloat strokeWidth = [self strokeWidthForVelocity:velocity];
            
            self.bezierPath.startWidthPercent = self.lastWidth / CGRectGetWidth(self.frame);
            self.bezierPath.endWidthPercent = strokeWidth / CGRectGetWidth(self.frame);
            
            self.lastWidth = strokeWidth;
            self.lastVelocity = velocity;
        }
        
        self.pointsArray[0] = self.pointsArray[3];
        self.pointsArray[1] = self.pointsArray[4];
        
        self.bezierPath = nil;
        [self setNeedsDisplay];
        
        [self.pointsArray removeLastObject];
        [self.pointsArray removeLastObject];
        [self.pointsArray removeLastObject];
        self.pointsCounter = 1;
    }
}

- (void)drawTouchEnded
{
    self.bezierPath = nil;
    self.lastVelocity = self.initialVelocity;
    self.lastWidth = self.strokeWidth;
    if (self.pointsArray.count == 1 && [[self.pointsArray lastObject] isKindOfClass:[JotTouchPoint class]]) {
        JotTouchPoint *touchPoint = [self.pointsArray lastObject];
        touchPoint.strokeWidthPercent = self.strokeWidth / CGRectGetWidth(self.frame);
        touchPoint.strokeColor = self.strokeColor;
        [self.pathsArray addObject:touchPoint];
    }
    [self setNeedsDisplay];
    [self.pathsCounts addObject:@(self.pathsArray.count)];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    [self drawAllPathsInFrame:rect];
}

- (CGFloat)strokeWidthForVelocity:(CGFloat)velocity
{
    return self.strokeWidth - ((self.strokeWidth * (1.f - kJotRelativeMinStrokeWidth)) / (1.f + (CGFloat)pow((double)M_E, (double)(-((velocity - self.initialVelocity) / self.initialVelocity)))));
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    _strokeColor = strokeColor;
    self.bezierPath = nil;
}

- (JotTouchBezier *)bezierPath
{
    if (!_bezierPath) {
        _bezierPath = [JotTouchBezier withColor:self.strokeColor];
        [self.pathsArray addObject:_bezierPath];
        _bezierPath.constantWidth = self.constantStrokeWidth;
        _bezierPath.erase = self.mode == JotDrawViewModeErase;
    }
    
    return _bezierPath;
}

#pragma mark - Image Rendering

- (UIImage *)renderDrawingWithSize:(CGSize)size
{
    return [self drawAllPathsImageWithSize:size
                           backgroundImage:nil];
}

- (UIImage *)drawOnImage:(UIImage *)image
{
    return [self drawAllPathsImageWithSize:image.size backgroundImage:image];
}

- (UIImage *)drawAllPathsImageWithSize:(CGSize)size backgroundImage:(UIImage *)backgroundImage
{
    CGFloat scale = size.width / CGRectGetWidth(self.bounds);
    
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, scale);
    [self drawAllPathsInFrame:CGRectMake(0, 0, size.width, size.height)];
    UIImage *pathsImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (!backgroundImage) {
        return [UIImage imageWithCGImage:pathsImage.CGImage scale:1.f orientation:pathsImage.imageOrientation];
    }

    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, scale);
        
    CGFloat imageAspectRatio = backgroundImage.size.width / backgroundImage.size.height;
    CGSize imageCanvassSize = CGSizeMake(CGRectGetWidth(self.bounds), CGRectGetWidth(self.bounds) / imageAspectRatio);
    if (imageCanvassSize.height > CGRectGetHeight(self.bounds)) {
        imageCanvassSize = CGSizeMake(CGRectGetHeight(self.bounds) * imageAspectRatio, CGRectGetHeight(self.bounds));
    }
    CGRect imageRect = CGRectMake(
        (self.bounds.size.width / 2) - imageCanvassSize.width / 2,
        (self.bounds.size.height / 2) - imageCanvassSize.height / 2,
        imageCanvassSize.width,
        imageCanvassSize.height
    );
    [backgroundImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
    [pathsImage drawInRect:imageRect];
    
    UIImage *drawnImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [UIImage imageWithCGImage:drawnImage.CGImage
                               scale:1.f
                         orientation:drawnImage.imageOrientation];
}

- (void)drawAllPathsInFrame:(CGRect)frame
{
    for (NSObject *path in self.pathsArray) {
        if ([path isKindOfClass:[JotTouchBezier class]]) {
            [(JotTouchBezier *)path jotDrawBezierInFrame:frame];
        } else if ([path isKindOfClass:[JotTouchPoint class]]) {
            JotTouchPoint *touchPoint = (JotTouchPoint*)path;
            [[touchPoint strokeColor] setFill];
            CGPoint originalPoint = [touchPoint CGPointValueInFrame:frame];
            [JotTouchBezier jotDrawBezierPoint:originalPoint withWidth:touchPoint.strokeWidthPercent inFrame:frame];
        }
    }
}

@end

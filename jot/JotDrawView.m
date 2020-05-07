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

@property (nonatomic, strong) NSMutableArray *pathsArray;
@property (nonatomic, strong) NSMutableArray<NSNumber*> *pathsCounts;
@property (nonatomic, strong) JotTouchBezier *bezierPath;
@property (nonatomic, strong) NSMutableArray *pointsArray;
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

#pragma mark - Undo

- (void) undo {
    [self.pathsCounts removeLastObject];
    NSInteger lastCount = [[self.pathsCounts lastObject] integerValue];
    while (self.pathsArray.count > lastCount) {
        [self.pathsArray removeLastObject];
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
    [self.pathsArray removeAllObjects];
    [self.pathsCounts removeAllObjects];
    
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

- (void)drawTouchBeganAtPoint:(CGPoint)touchPoint
{
    self.lastVelocity = self.initialVelocity;
    self.lastWidth = self.strokeWidth;
    
    if (self.mode == JotDrawViewModeStraightLines) {
        self.bezierPath = nil;
        CGPoint snappedPoint = touchPoint;
        for (id path in self.pathsArray) {
            if ([path isKindOfClass:[JotTouchPoint class]]) {
                JotTouchPoint *point = (JotTouchPoint*)path;
                if ([self isPoint:touchPoint closeToPoint:point.point]) {
                    snappedPoint = point.point;
                }
            } else if ([path isKindOfClass:[JotTouchBezier class]]) {
                JotTouchBezier *touchPath = (JotTouchBezier*)path;
                if ([self isPoint:touchPoint closeToPoint:touchPath.startPoint]) {
                    snappedPoint = touchPath.startPoint;
                    break;
                } else if ([self isPoint:touchPoint closeToPoint:touchPath.endPoint]) {
                    snappedPoint = touchPath.endPoint;
                    break;
                }
            }

        }
        self.bezierPath.startPoint = snappedPoint;
        self.bezierPath.endPoint = snappedPoint;
        self.bezierPath.startWidth = self.strokeWidth;
        self.bezierPath.endWidth = self.strokeWidth;
        self.bezierPath.straightLine = YES;
        return;
    }

    self.pointsCounter = 0;
    [self.pointsArray removeAllObjects];
    [self.pointsArray addObject:[JotTouchPoint withPoint:touchPoint]];
}

- (void)drawTouchMovedToPoint:(CGPoint)touchPoint
{
    if (self.mode == JotDrawViewModeStraightLines) {
        CGPoint snappedPoint = touchPoint;
        if ([self isAxis:touchPoint.x closeToAxis:self.bezierPath.startPoint.x]) {
            snappedPoint.x = self.bezierPath.startPoint.x;
        }
        // if x has been snapped, do not snap y
        if (snappedPoint.x != self.bezierPath.startPoint.x && [self isAxis:touchPoint.y closeToAxis:self.bezierPath.startPoint.y]) {
            snappedPoint.y = self.bezierPath.startPoint.y;
        }
        CGFloat oldDifferenceX = CGFLOAT_MAX;
        CGFloat oldDifferenceY = CGFLOAT_MAX;
        // Iterate through all existing paths to see if the touch is close to any other point's axis
        for (id pathObject in self.pathsArray) {
            if ([pathObject isKindOfClass:[JotTouchBezier class]]) {
                JotTouchBezier *path = (JotTouchBezier*)pathObject;
                // if the path is not a straight line or is our current path, ignore it
                if (path.straightLine && path != self.bezierPath) {
                    if ([self isAxis:touchPoint.x closeToAxis:path.startPoint.x]) {
                        CGFloat newDifference = fabs(touchPoint.x - path.startPoint.x);
                        if (newDifference < oldDifferenceX) {
                            oldDifferenceX = newDifference;
                            snappedPoint.x = path.startPoint.x;
                        }
                    }
                    if ([self isAxis:touchPoint.x closeToAxis:path.endPoint.x]) {
                        CGFloat newDifference = fabs(touchPoint.x - path.endPoint.x);
                        if (newDifference < oldDifferenceX) {
                            oldDifferenceX = newDifference;
                            snappedPoint.x = path.endPoint.x;
                        }
                    }
                    if ([self isAxis:touchPoint.y closeToAxis:path.startPoint.y]) {
                        CGFloat newDifference = fabs(touchPoint.y - path.startPoint.y);
                        if (newDifference < oldDifferenceY) {
                            oldDifferenceY = newDifference;
                            snappedPoint.y = path.startPoint.y;
                        }
                    }
                    if ([self isAxis:touchPoint.y closeToAxis:path.endPoint.y]) {
                        CGFloat newDifference = fabs(touchPoint.y - path.endPoint.y);
                        if (newDifference < oldDifferenceY) {
                            oldDifferenceY = newDifference;
                            snappedPoint.y = path.endPoint.y;
                        }
                    }
                }
            }
            
        }
        self.bezierPath.endPoint = snappedPoint;
        [self setNeedsDisplay];
        return;
    }
    
    self.pointsCounter += 1;
    [self.pointsArray addObject:[JotTouchPoint withPoint:touchPoint]];
    
    if (self.pointsCounter == 4) {
        
        self.pointsArray[3] = [JotTouchPoint withPoint:CGPointMake(([self.pointsArray[2] CGPointValue].x + [self.pointsArray[4] CGPointValue].x)/2.f,
                                                                   ([self.pointsArray[2] CGPointValue].y + [self.pointsArray[4] CGPointValue].y)/2.f)];
        
        self.bezierPath.startPoint = [self.pointsArray[0] CGPointValue];
        self.bezierPath.endPoint = [self.pointsArray[3] CGPointValue];
        self.bezierPath.controlPoint1 = [self.pointsArray[1] CGPointValue];
        self.bezierPath.controlPoint2 = [self.pointsArray[2] CGPointValue];
        
        if (self.constantStrokeWidth) {
            self.bezierPath.startWidth = self.strokeWidth;
            self.bezierPath.endWidth = self.strokeWidth;
        } else {
            CGFloat velocity = [(JotTouchPoint *)self.pointsArray[3] velocityFromPoint:(JotTouchPoint *)self.pointsArray[0]];
            velocity = (kJotVelocityFilterWeight * velocity) + ((1.f - kJotVelocityFilterWeight) * self.lastVelocity);
            
            CGFloat strokeWidth = [self strokeWidthForVelocity:velocity];
            
            self.bezierPath.startWidth = self.lastWidth;
            self.bezierPath.endWidth = strokeWidth;
            
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
    [self.pathsCounts addObject:@(self.pathsArray.count)];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    [self drawAllPaths];
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
    [self drawAllPaths];
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

- (void)drawAllPaths
{
    for (NSObject *path in self.pathsArray) {
        if ([path isKindOfClass:[JotTouchBezier class]]) {
            [(JotTouchBezier *)path jotDrawBezier];
        } else if ([path isKindOfClass:[JotTouchPoint class]]) {
            [[(JotTouchPoint *)path strokeColor] setFill];
            [JotTouchBezier jotDrawBezierPoint:[(JotTouchPoint *)path CGPointValue]
                                     withWidth:[(JotTouchPoint *)path strokeWidth]];
        }
    }
}

@end

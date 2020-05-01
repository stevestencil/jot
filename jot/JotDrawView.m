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

@interface JotDrawView ()

@property (nonatomic, strong) UIImage *cachedImage;
@property (nonatomic, strong) NSMutableArray<UIImage*> *cachedImages;

@property (nonatomic, strong) NSMutableArray *pathsArray;

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
                
        _strokeWidth = 10.f;
        _strokeColor = [UIColor blackColor];
        
        _pathsArray = [NSMutableArray array];
        
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
    [self.cachedImages removeLastObject];
    UIImage *previousImage = [self.cachedImages lastObject];
    self.cachedImage = previousImage;
    [self setNeedsDisplay];
    [UIView transitionWithView:self duration:0.2f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self setNeedsDisplay];
                    }
                    completion:nil];
}

- (void)clearDrawing
{
    self.cachedImage = nil;
    [self.cachedImages removeAllObjects];
    
    [self.pathsArray removeAllObjects];
    
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

- (void)drawTouchBeganAtPoint:(CGPoint)touchPoint
{
    self.lastVelocity = self.initialVelocity;
    self.lastWidth = self.strokeWidth;
    self.pointsCounter = 0;
    [self.pointsArray removeAllObjects];
    [self.pointsArray addObject:[JotTouchPoint withPoint:touchPoint]];
}

- (void)drawTouchMovedToPoint:(CGPoint)touchPoint
{
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
        
        [self drawBitmap];
        
        [self.pointsArray removeLastObject];
        [self.pointsArray removeLastObject];
        [self.pointsArray removeLastObject];
        self.pointsCounter = 1;
    }
}

- (void)drawTouchEnded
{
    if (self.cachedImage) {
        [self.cachedImages addObject:self.cachedImage];
    }
    [self drawBitmap];
    self.lastVelocity = self.initialVelocity;
    self.lastWidth = self.strokeWidth;
}

#pragma mark - Drawing

// - (void) drawGridIfNeeded {
//     if (self.shouldDrawGrid) {
//         CGFloat size = self.gridSize;
//         CGFloat x = fmod(CGRectGetWidth(self.frame), size) / 2;
//         [[self.gridColor colorWithAlphaComponent:0.5] setStroke];
//         UIBezierPath *path = [[UIBezierPath alloc] init];
//         [path moveToPoint:CGPointMake(x, 0)];
//         [path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.frame))];
//         while (x < CGRectGetWidth(self.frame)) {
//             [path moveToPoint:CGPointMake(x + size, 0)];
//             [path addLineToPoint:CGPointMake(x + size, CGRectGetMaxY(self.frame))];
//             x += size;
//         }
//         NSInteger y = fmod(CGRectGetHeight(self.frame), size) / 2;
//         [path moveToPoint:CGPointMake(0, y)];
//         [path addLineToPoint:CGPointMake(CGRectGetMaxX(self.frame), y)];
//         while (y < CGRectGetHeight(self.frame)) {
//             [path moveToPoint:CGPointMake(0, y + size)];
//             [path addLineToPoint:CGPointMake(CGRectGetMaxX(self.frame), y + size)];
//             y += size;
//         }
//         [path stroke];
//     }
// }

- (void)drawBitmap
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
    
    if (self.cachedImage) {
        [self.cachedImage drawInRect:self.frame];
    }

    [self.bezierPath jotDrawBezier];
    self.bezierPath = nil;
    
    if (self.pointsArray.count == 1) {
        JotTouchPoint *touchPoint = [self.pointsArray firstObject];
        touchPoint.strokeColor = self.strokeColor;
        touchPoint.strokeWidth = 1.5f * [self strokeWidthForVelocity:1.f];
        [self.pathsArray addObject:touchPoint];
        [touchPoint.strokeColor setFill];
        [JotTouchBezier jotDrawBezierPoint:[touchPoint CGPointValue]
                                 withWidth:touchPoint.strokeWidth];
    }
    
    self.cachedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    [self.cachedImage drawInRect:rect];
    [self.bezierPath jotDrawBezier];
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
    [backgroundImage drawInRect:imageRect];
    [self drawAllPaths];
    
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

#pragma mark - Setters & Getters

- (NSMutableArray<UIImage *> *)cachedImages {
    if (!_cachedImages) {
        _cachedImages = [NSMutableArray new];
    }
    return _cachedImages;
}

@end

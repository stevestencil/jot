//
//  JotTouchBezier.m
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import "JotTouchBezier.h"

NSUInteger const kJotDrawStepsPerBezier = 300;

@implementation JotTouchBezier

+ (instancetype)withColor:(UIColor *)color
{
    JotTouchBezier *touchBezier = [JotTouchBezier new];
    
    touchBezier.strokeColor = color;
    
    return touchBezier;
}

- (void)jotDrawBezierInFrame:(CGRect)frame
{
    CGPoint startPoint =  CGPointMake(CGRectGetWidth(frame) * self.startPointPercent.x,
                                      CGRectGetHeight(frame) * self.startPointPercent.y);
    CGPoint endPoint = CGPointMake(CGRectGetWidth(frame) * self.endPointPercent.x,
                                   CGRectGetHeight(frame) * self.endPointPercent.y);
    CGPoint controlPoint1 = CGPointMake(CGRectGetWidth(frame) * self.controlPoint1Percent.x,
                                        CGRectGetHeight(frame) * self.controlPoint1Percent.y);
    CGPoint controlPoint2 = CGPointMake(CGRectGetWidth(frame) * self.controlPoint2Percent.x,
                                        CGRectGetHeight(frame) * self.controlPoint2Percent.y);
    if (self.straightLine) {
        UIBezierPath *bezierPath = [UIBezierPath new];
        [bezierPath moveToPoint:startPoint];
        [bezierPath addLineToPoint:endPoint];
        bezierPath.lineWidth = self.startWidthPercent * CGRectGetWidth(frame);
        bezierPath.lineCapStyle = kCGLineCapRound;
        [self.strokeColor setStroke];
        [bezierPath strokeWithBlendMode:self.erase ? kCGBlendModeClear : kCGBlendModeNormal alpha:1.f];
    } else if (self.constantWidth) {
        UIBezierPath *bezierPath = [UIBezierPath new];
        [bezierPath moveToPoint:startPoint];
        [bezierPath addCurveToPoint:endPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
        bezierPath.lineWidth = self.startWidthPercent * CGRectGetWidth(frame);
        bezierPath.lineCapStyle = kCGLineCapRound;
        [self.strokeColor setStroke];
        [bezierPath strokeWithBlendMode:self.erase ? kCGBlendModeClear : kCGBlendModeNormal alpha:1.f];
    } else {
        [self.strokeColor setFill];
        
        CGFloat widthDelta = (self.endWidthPercent * CGRectGetWidth(frame)) - (self.startWidthPercent * CGRectGetWidth(frame));
        
        for (NSUInteger i = 0; i < kJotDrawStepsPerBezier; i++) {
            
            CGFloat t = ((CGFloat)i) / (CGFloat)kJotDrawStepsPerBezier;
            CGFloat tt = t * t;
            CGFloat ttt = tt * t;
            CGFloat u = 1.f - t;
            CGFloat uu = u * u;
            CGFloat uuu = uu * u;
            
            CGFloat x = uuu * startPoint.x;
            x += 3 * uu * t * controlPoint1.x;
            x += 3 * u * tt * controlPoint2.x;
            x += ttt * endPoint.x;
            
            CGFloat y = uuu * startPoint.y;
            y += 3 * uu * t * controlPoint1.y;
            y += 3 * u * tt * controlPoint2.y;
            y += ttt * endPoint.y;
            
            CGFloat pointWidth = ((self.startWidthPercent * CGRectGetWidth(frame)) + (ttt * widthDelta)) / CGRectGetWidth(frame);
            CGPoint translatedPoint = CGPointMake(x * CGRectGetWidth(frame), y * CGRectGetHeight(frame));
            [self.class jotDrawBezierPoint:CGPointMake(x, y) withWidth:pointWidth inFrame:frame];
        }
    }
}

+ (void)jotDrawBezierPoint:(CGPoint)point withWidth:(CGFloat)width inFrame:(CGRect)frame
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }
    CGPoint translatedPoint = CGPointMake(point.x * CGRectGetWidth(frame), point.y * CGRectGetHeight(frame));
    CGFloat translatedWidth = width * CGRectGetWidth(frame);
    CGContextFillEllipseInRect(context, CGRectInset(CGRectMake(translatedPoint.x, translatedPoint.y, 0.f, 0.f), -translatedWidth / 2.f, -translatedWidth / 2.f));
}

@end

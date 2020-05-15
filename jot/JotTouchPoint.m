//
//  JotTouchPoint.m
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import "JotTouchPoint.h"

@implementation JotTouchPoint

+ (instancetype)withPoint:(CGPoint)point inFrame:(CGRect)frame
{
    JotTouchPoint *touchPoint = [JotTouchPoint new];
    touchPoint.pointPercent = CGPointMake(point.x / CGRectGetWidth(frame), point.y / CGRectGetHeight(frame));
    touchPoint.timestamp = [NSDate date];
    return touchPoint;
}

- (CGFloat)velocityFromPoint:(JotTouchPoint *)fromPoint inFrame:(CGRect)frame
{
    CGPoint translatedPoint = [self CGPointValueInFrame:frame];
    CGPoint translatedFromPoint = CGPointMake(fromPoint.pointPercent.x * CGRectGetWidth(frame), fromPoint.pointPercent.y * CGRectGetHeight(frame));
    CGFloat distance = (CGFloat)sqrt((double)(pow((double)(translatedPoint.x - translatedFromPoint.x),
                                                  (double)2.f)
                                              + pow((double)(translatedPoint.y - translatedFromPoint.y),
                                                    (double)2.f)));
    
    CGFloat timeInterval = (CGFloat)fabs((double)([self.timestamp timeIntervalSinceDate:fromPoint.timestamp]));
    return distance / timeInterval;
}

- (CGPoint)CGPointValueInFrame:(CGRect)frame
{
    return CGPointMake(self.pointPercent.x * CGRectGetWidth(frame), self.pointPercent.y * CGRectGetHeight(frame));
}

@end

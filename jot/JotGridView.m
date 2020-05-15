//
//  JotGridView.m
//  Pods
//
//  Created by Steve Stencil on 5/7/20.
//

#import "JotGridView.h"

@implementation JotGridView

@synthesize gridColor = _gridColor;
@synthesize gridSize = _gridSize;

- (void) initialize {
    self.backgroundColor = [UIColor clearColor];
    self.hidden = YES;
}

- (instancetype)init {
    if (self = [super init]) {
        [self initialize];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initialize];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self initialize];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [self.gridColor setStroke];
    [self.gridPath stroke];
}

- (UIImage *)drawImageForSize:(CGSize)size
{
    CGFloat scale = size.width / CGRectGetWidth(self.bounds);
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, scale);
    [self.gridColor setStroke];
    [self.gridPath stroke];
    UIImage *pathsImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return pathsImage;
}

#pragma mark - Setters & Getters

- (UIBezierPath *)gridPath {
    if (!_gridPath) {
        CGFloat size = MAX(self.gridSize, 1);
        CGFloat xOffset = fmod(CGRectGetWidth(self.frame), size) / 2;
        CGFloat yOffset = fmod(CGRectGetHeight(self.frame), size) / 2;
        CGFloat x = xOffset;
        UIBezierPath *path = [[UIBezierPath alloc] init];
        [path moveToPoint:CGPointMake(x, yOffset)];
        [path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.frame) - yOffset)];
        while (x < CGRectGetWidth(self.frame)) {
            [path moveToPoint:CGPointMake(x + size, yOffset)];
            [path addLineToPoint:CGPointMake(x + size, CGRectGetMaxY(self.frame) - yOffset)];
            x += size;
        }
        
        NSInteger y = yOffset;
        [path moveToPoint:CGPointMake(xOffset, y)];
        [path addLineToPoint:CGPointMake(CGRectGetMaxX(self.frame) - xOffset, y)];
        while (y < CGRectGetHeight(self.frame)) {
            [path moveToPoint:CGPointMake(xOffset, y + size)];
            [path addLineToPoint:CGPointMake(CGRectGetMaxX(self.frame) - xOffset, y + size)];
            y += size;
        }
        _gridPath = path;
    }
    return _gridPath;
}

- (UIColor*) gridColor {
    if (!_gridColor) {
        _gridColor = [UIColor colorWithRed:150/255.0f green:173/255.0f blue:233/255.0 alpha:1.0f];
    }
    return _gridColor;
}

- (void)setGridColor:(UIColor *)gridColor {
    _gridColor = gridColor;
    [self setNeedsDisplay];
}

- (CGFloat)gridSize {
    if (_gridSize <= 0) {
        _gridSize = 30.0;
    }
    return _gridSize;
}

- (void)setGridSize:(CGFloat)gridSize {
    _gridSize = gridSize;
    self.gridPath = nil;
    self.hidden = gridSize <= 0;
    [self setNeedsDisplay];
}

@end

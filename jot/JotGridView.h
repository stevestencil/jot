//
//  JotGridView.h
//  Pods
//
//  Created by Steve Stencil on 5/7/20.
//

#import <UIKit/UIKit.h>

@interface JotGridView : UIView

@property (nonatomic, strong) UIBezierPath *gridPath;

@property (nonatomic, assign) CGFloat gridSize;
@property (nonatomic, strong) UIColor *gridColor;

- (UIImage *)drawImageForSize:(CGSize)size;

@end

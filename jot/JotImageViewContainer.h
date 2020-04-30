//
//  JotImageViewContainer.h
//  Pods
//
//  Created by Steve Stencil on 4/29/20.
//

#import <UIKit/UIKit.h>

@interface JotImageViewContainer : UIView

+ (instancetype) imageViewContainerWithImage:(UIImage*)image;

@property (weak, nonatomic, readonly) UIImageView *imageView;
@property (nonatomic) CGFloat scale;

@end

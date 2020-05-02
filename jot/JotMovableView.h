//
//  JotImageViewContainer.h
//  Pods
//
//  Created by Steve Stencil on 4/29/20.
//

#import <UIKit/UIKit.h>

#define DEGREES_TO_RADIANS(x) (M_PI * (x) / 180.0)
#define RADIANS_TO_DEGREES(x) (x * (180 / M_PI))

typedef enum {
    JotMovableViewContainerTypeImage,
} JotMovableViewContainerType;

@interface JotMovableView : UIView

+ (instancetype) imageViewContainerWithImage:(UIImage*)image;

@property (nonatomic, readonly) JotMovableViewContainerType type;
@property (nonatomic, readonly) UIImage *image;

- (void) setSelected:(BOOL)selected;
- (void) resizeWithSize:(CGSize)size;
- (void) resizeWithScale:(CGFloat)scale;
- (void) moveViewToCenter:(CGPoint)center;
- (void) captureUndoObject;
- (instancetype) undo;

@end

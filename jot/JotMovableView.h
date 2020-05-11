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
    JotMovableViewContainerTypeText
} JotMovableViewContainerType;

@class JotMovableView;

@protocol JotMovableViewDelegate <NSObject>

@optional
- (void) jotMovableView:(JotMovableView*)view didBeginUpdateText:(NSString*)text;
- (void) jotMovableView:(JotMovableView*)view didEndUpdateText:(NSString*)text;

@end

@interface JotMovableView : UIView

+ (instancetype) movableViewWithImage:(UIImage*)image;
+ (instancetype) movableViewWithText:(NSString*)text;

@property (nonatomic, strong) id <JotMovableViewDelegate> delegate;
@property (nonatomic, readonly) JotMovableViewContainerType type;
@property (nonatomic, strong, readonly) UIImage *image;
@property (nonatomic) BOOL isEditing;

- (void) setSelected:(BOOL)selected;
- (void) resizeWithSize:(CGSize)size;
- (void) resizeWithScale:(CGFloat)scale;
- (void) moveViewToCenter:(CGPoint)center;
- (void) resizeWithScale:(CGFloat)scale moveToCenter:(CGPoint)center;
- (void) resizeWithSize:(CGSize)size moveToCenter:(CGPoint)center;
- (void) captureUndoObject;
- (instancetype) undo;

- (NSAttributedString*) attributedString;
- (void) setFontColor:(UIColor*)color;

@end

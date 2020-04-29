//
//  JotImageView.h
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import <UIKit/UIKit.h>

@class JotImageView;

@protocol JotImageViewDelegate <NSObject>

- (void) jotImageView:(JotImageView*)jotImageView didBeginMovingImageView:(UIImageView*)imageView;
- (void) jotImageView:(JotImageView *)jotImageView didMoveImageView:(UIImageView *)imageView;
- (void) jotImageView:(JotImageView*)jotImageView didEndMovingImageView:(UIImageView*)imageView;

@end

@interface JotImageView : UIView

@property (weak, nonatomic) id <JotImageViewDelegate> delegate;
@property (nonatomic, readonly) NSInteger imageCount;
@property (nonatomic, readonly) BOOL isMovingView;

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer;
- (void)handlePinchOrRotateGesture:(UIGestureRecognizer *)recognizer;
- (UIImage*) renderImage;
- (void)addImageView:(UIImage*)image;
- (void) clearImages;
- (void) cancelEditing;

@end

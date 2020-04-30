//
//  JotImageView.h
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import <UIKit/UIKit.h>
#import "JotImageViewContainer.h"

@class JotImageView;

@protocol JotImageViewDelegate <NSObject>

- (void) jotImageView:(JotImageView*)jotImageView didBeginMovingImageView:(JotImageViewContainer*)imageView;
- (void) jotImageView:(JotImageView *)jotImageView didMoveImageView:(JotImageViewContainer *)imageView;
- (void) jotImageView:(JotImageView*)jotImageView didEndMovingImageView:(JotImageViewContainer*)imageView;

@end

@interface JotImageView : UIView

@property (weak, nonatomic) id <JotImageViewDelegate> delegate;
@property (nonatomic, readonly) NSInteger imageCount;
@property (nonatomic, readonly) BOOL isMovingView;

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer;
- (void) handlePinchGesture:(UIPinchGestureRecognizer*)recognizer;
- (void) handleRotateGesture:(UIRotationGestureRecognizer*)recognizer;
- (UIImage*) renderImage;
- (void)addImageView:(UIImage*)image;
- (void) clearImages;
- (void) cancelEditing;

@end

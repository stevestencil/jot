//
//  JotImageView.h
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import <UIKit/UIKit.h>
#import "JotImageViewContainer.h"

@class JotMovableViewContainer;

@protocol JotImageViewDelegate <NSObject>

- (void) jotImageView:(JotMovableViewContainer*)jotImageView didBeginMovingImageView:(JotImageViewContainer*)imageView;
- (void) jotImageView:(JotMovableViewContainer *)jotImageView didMoveImageView:(JotImageViewContainer *)imageView;
- (void) jotImageView:(JotMovableViewContainer*)jotImageView didEndMovingImageView:(JotImageViewContainer*)imageView;
- (void) jotImageViewDidCaptureUndoSnapshot:(JotMovableViewContainer*)jotImageView;

@end

@interface JotMovableViewContainer : UIView

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
- (void) undo;

@end

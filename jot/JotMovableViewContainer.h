//
//  JotImageView.h
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import <UIKit/UIKit.h>

@class JotMovableViewContainer;

@protocol JotMovableViewContainerDelegate <NSObject>

- (void) jotMovableViewContainerUndoSnapshot:(JotMovableViewContainer*)movableViewContainer;

@end

@interface JotMovableViewContainer : UIView

@property (weak, nonatomic) id <JotMovableViewContainerDelegate> delegate;
@property (nonatomic, readonly) NSInteger viewCount;
@property (nonatomic, readonly) BOOL isMovingView;

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer;
- (void) handlePinchGesture:(UIPinchGestureRecognizer*)recognizer;
- (void) handleRotateGesture:(UIRotationGestureRecognizer*)recognizer;
- (UIImage*) renderImage;
- (void)addImageView:(UIImage*)image;
- (void) clearAll;
- (void) cancelEditing;
- (void) undo;

@end

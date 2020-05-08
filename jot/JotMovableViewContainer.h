//
//  JotImageView.h
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import <UIKit/UIKit.h>
#import "JotMovableView.h"

@class JotMovableViewContainer;

@protocol JotMovableViewContainerDelegate <NSObject>

- (void) jotMovableViewContainerUndoSnapshot:(JotMovableViewContainer*)movableViewContainer;

@end

@interface JotMovableViewContainer : UIView

@property (weak, nonatomic) id <JotMovableViewContainerDelegate> delegate;
@property (nonatomic, readonly) NSInteger viewCount;
@property (nonatomic, readonly) BOOL isMovingView;

- (JotMovableView*) handleTapGesture:(UITapGestureRecognizer*)recognizer;
- (JotMovableView*) handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer;
- (JotMovableView*) handlePanGesture:(UIPanGestureRecognizer*)recognizer;
- (void) handlePinchGesture:(UIPinchGestureRecognizer*)recognizer;
- (void) handleRotateGesture:(UIRotationGestureRecognizer*)recognizer;

- (UIImage*) renderImage;
- (UIImage*) renderImageOnImage:(UIImage*)image;
- (void)addImageView:(UIImage*)image;
- (void) addTextViewWithText:(NSString*)text;
- (void) clearAll;
- (void) cancelEditing;
- (void) undo;

@end

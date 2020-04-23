//
//  JotImageView.h
//  Pods
//
//  Created by Steve Stencil on 4/21/20.
//

#import <UIKit/UIKit.h>

@interface JotImageView : UIView

@property (nonatomic, readonly) NSInteger imageCount;
@property (nonatomic, readonly) BOOL isMovingView;

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer;
- (void)handlePinchOrRotateGesture:(UIGestureRecognizer *)recognizer;
- (UIImage*) renderImage;
- (void)addImageView:(UIImage*)image;
- (void) clearImages;

@end

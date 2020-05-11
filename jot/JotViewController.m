//
//  JotViewController.m
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import "JotViewController.h"
#import "JotDrawView.h"
#import "JotTextView.h"
#import "JotTextEditView.h"
#import <Masonry/Masonry.h>
#import "UIImage+Jot.h"
#import "JotDrawingContainer.h"
#import "JotMovableViewContainer.h"
//#import "JotMovableView.h"
#import "JotGridView.h"

@interface JotViewController () <UIGestureRecognizerDelegate, JotTextEditViewDelegate, JotDrawingContainerDelegate, JotMovableViewContainerDelegate>

@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchRecognizer;
@property (nonatomic, strong) UIRotationGestureRecognizer *rotationRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panRecognizer;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressRecognizer;
@property (nonatomic, strong, readwrite) JotDrawingContainer *drawingContainer;
@property (nonatomic, strong) JotDrawView *drawView;
//@property (nonatomic, strong) JotTextEditView *textEditView;
//@property (nonatomic, strong) JotTextView *textView;
@property (nonatomic, strong) JotMovableViewContainer *movableView;
@property (nonatomic, strong) JotGridView *gridView;
@property (nonatomic, strong) NSMutableArray<__kindof UIView*> *viewsInEditOrder;

@end

@implementation JotViewController

- (instancetype)init
{
    if ((self = [super init])) {
        
        _drawView = [JotDrawView new];
//        _textEditView = [JotTextEditView new];
//        _textEditView.delegate = self;
//        _textView = [JotTextView new];
        _drawingContainer = [JotDrawingContainer new];
        self.drawingContainer.delegate = self;
        _movableView = [JotMovableViewContainer new];
        self.movableView.delegate = self;
        
        JotGridView *gridView = [[JotGridView alloc] init];
        self.gridView = gridView;
        
//        _font = self.textView.font;
//        self.textEditView.font = self.font;
//        _fontSize = self.textView.fontSize;
//        self.textEditView.fontSize = self.fontSize;
//        _textAlignment = self.textView.textAlignment;
//        self.textEditView.textAlignment = NSTextAlignmentLeft;
//        _textColor = self.textView.textColor;
//        self.textEditView.textColor = self.textColor;
        _textString = @"";
        _drawingColor = self.drawView.strokeColor;
        _drawingStrokeWidth = self.drawView.strokeWidth;
//        _textEditingInsets = self.textEditView.textEditingInsets;
//        _initialTextInsets = self.textView.initialTextInsets;
        _state = JotViewStateDefault;
        
        _pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
        self.pinchRecognizer.delegate = self;
        
        _rotationRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotateGesture:)];
        self.rotationRecognizer.delegate = self;
        
        _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
        self.panRecognizer.delegate = self;
        
        _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        self.tapRecognizer.delegate = self;
        
        _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
        self.longPressRecognizer.delegate = self;
    }
    
    return self;
}

- (void)dealloc
{
//    self.textEditView.delegate = nil;
    self.drawingContainer.delegate = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.drawingContainer.clipsToBounds = YES;
    
    [self.view addSubview:self.gridView];
    [self.gridView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
    
    [self.view addSubview:self.movableView];
    [self.movableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.view addSubview:self.drawingContainer];
    [self.drawingContainer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.drawingContainer addSubview:self.drawView];
    [self.drawView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.drawingContainer);
    }];
    
//    [self.drawingContainer addSubview:self.textView];
//    [self.textView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.edges.equalTo(self.drawingContainer);
//    }];
    
//    [self.view addSubview:self.textEditView];
//    [self.textEditView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.edges.equalTo(self.view);
//    }];
    
    [self.drawingContainer addGestureRecognizer:self.tapRecognizer];
    [self.drawingContainer addGestureRecognizer:self.panRecognizer];
    [self.drawingContainer addGestureRecognizer:self.rotationRecognizer];
    [self.drawingContainer addGestureRecognizer:self.pinchRecognizer];
    [self.drawingContainer addGestureRecognizer:self.longPressRecognizer];
}

#pragma mark - Properties

- (void)setState:(JotViewState)state
{
    if (_state != state) {
        _state = state;
        
//        self.textView.hidden =
//        self.textEditView.isEditing = (state == JotViewStateEditingText);
        
        if (state == JotViewStateEditingText
            && [self.delegate respondsToSelector:@selector(jotViewController:isEditingText:)]) {
            [self.delegate jotViewController:self isEditingText:YES];
        }
        self.drawingContainer.multipleTouchEnabled =
        self.tapRecognizer.enabled =
        self.panRecognizer.enabled =
        self.pinchRecognizer.enabled =
        self.rotationRecognizer.enabled = (state == JotViewStateText) || (state == JotViewStateImage);
        
        if (state != JotViewStateImage && state != JotViewStateText) {
            [self.movableView cancelEditing];
        }
        
        self.drawView.mode = JotDrawViewModeStandard;
        if (state == JotViewStateStraightLineDrawing) {
            self.drawView.mode = JotDrawViewModeStraightLines;
        } else if (state == JotViewStateErase) {
            self.drawView.mode = JotDrawViewModeErase;
        }
        
        if ([self.delegate respondsToSelector:@selector(jotViewController:didChangeState:)]) {
            [self.delegate jotViewController:self didChangeState:_state];
        }
    }
}

- (void)setTextString:(NSString *)textString
{
    if (![_textString isEqualToString:textString]) {
        _textString = textString;
//        if (![self.textView.textString isEqualToString:textString]) {
//            self.textView.textString = textString;
//        }
//        if (![self.textEditView.textString isEqualToString:textString]) {
//            self.textEditView.textString = textString;
//        }
    }
}

- (void)setFont:(UIFont *)font
{
    if (_font != font) {
        _font = font;
//        self.textView.font =
//        self.textEditView.font = font;
    }
}

- (void)setFontSize:(CGFloat)fontSize
{
    if (_fontSize != fontSize) {
        _fontSize = fontSize;
//        self.textView.fontSize =
//        self.textEditView.fontSize = fontSize;
    }
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
    if (_textAlignment != textAlignment) {
        _textAlignment = textAlignment;
//        self.textView.textAlignment =
//        self.textEditView.textAlignment = textAlignment;
    }
}

- (void)setTextColor:(UIColor *)textColor
{
    if (_textColor != textColor) {
        _textColor = textColor;
//        self.textView.textColor =
//        self.textEditView.textColor = textColor;
    }
}

- (void)setInitialTextInsets:(UIEdgeInsets)initialTextInsets
{
    if (!UIEdgeInsetsEqualToEdgeInsets(_initialTextInsets, initialTextInsets)) {
        _initialTextInsets = initialTextInsets;
//        self.textView.initialTextInsets = initialTextInsets;
    }
}

- (void)setTextEditingInsets:(UIEdgeInsets)textEditingInsets
{
    if (!UIEdgeInsetsEqualToEdgeInsets(_textEditingInsets, textEditingInsets)) {
        _textEditingInsets = textEditingInsets;
//        self.textEditView.textEditingInsets = textEditingInsets;
    }
}

- (void)setFitOriginalFontSizeToViewWidth:(BOOL)fitOriginalFontSizeToViewWidth
{
    if (_fitOriginalFontSizeToViewWidth != fitOriginalFontSizeToViewWidth) {
        _fitOriginalFontSizeToViewWidth = fitOriginalFontSizeToViewWidth;
//        self.textView.fitOriginalFontSizeToViewWidth = fitOriginalFontSizeToViewWidth;
//        if (fitOriginalFontSizeToViewWidth) {
//            self.textEditView.textAlignment = self.textAlignment;
//        } else {
//            self.textEditView.textAlignment = NSTextAlignmentLeft;
//        }
    }
}

- (void)setClipBoundsToEditingInsets:(BOOL)clipBoundsToEditingInsets
{
    if (_clipBoundsToEditingInsets != clipBoundsToEditingInsets) {
        _clipBoundsToEditingInsets = clipBoundsToEditingInsets;
//        self.textEditView.clipBoundsToEditingInsets = clipBoundsToEditingInsets;
    }
}

- (void)setDrawingColor:(UIColor *)drawingColor
{
    if (_drawingColor != drawingColor) {
        _drawingColor = drawingColor;
        self.drawView.strokeColor = drawingColor;
        [self.movableView setFontColor:drawingColor];
    }
}

- (void)setDrawingStrokeWidth:(CGFloat)drawingStrokeWidth
{
    if (_drawingStrokeWidth != drawingStrokeWidth) {
        _drawingStrokeWidth = drawingStrokeWidth;
        self.drawView.strokeWidth = drawingStrokeWidth;
    }
}

- (void)setDrawingConstantStrokeWidth:(BOOL)drawingConstantStrokeWidth
{
    if (_drawingConstantStrokeWidth != drawingConstantStrokeWidth) {
        _drawingConstantStrokeWidth = drawingConstantStrokeWidth;
        self.drawView.constantStrokeWidth = drawingConstantStrokeWidth;
    }
}

#pragma mark - Undo

- (void)clearAll
{
    [self clearDrawing];
    [self clearText];
    [self clearImages];
}

- (void)clearDrawing
{
    [self.drawView clearDrawing];
}

- (void) undo {
    id lastView = [self.viewsInEditOrder lastObject];
    [self.viewsInEditOrder removeLastObject];
    if ([lastView isKindOfClass:[JotMovableViewContainer class]]) {
        [(JotMovableView*)lastView undo];
    } else if ([lastView isKindOfClass:[JotDrawView class]]) {
        [(JotMovableView*)lastView undo];
    }
}

- (void)clearText
{
    self.textString = @"";
//    [self.textView clearText];
}

- (void)clearImages {
    [self.movableView clearAll];
}

#pragma mark - Movable Views

- (void)addBackgroundImage:(UIImage *)image {
    [self.movableView addImageView:image];
}

- (void)addTextViewWithText:(NSString *)text {
    [self.movableView addTextViewWithText:text];
    self.state = JotViewStateText;
}

- (BOOL)photosAdded {
    return self.movableView.viewCount > 0;
}

#pragma mark - Grid

- (void)setGridSize:(CGFloat)gridSize {
    self.gridView.gridSize = gridSize;
}

- (CGFloat)gridSize {
    return self.gridView.gridSize;
}

- (void)setGridColor:(UIColor *)gridColor {
    self.gridView.gridColor = gridColor;
}

- (UIColor *)gridColor {
    return self.gridView.gridColor;
}

- (BOOL)hasGrid {
    return !self.gridView.hidden;
}

- (void)setHasGrid:(BOOL)hasGrid {
    self.gridView.hidden = !hasGrid;
}

#pragma mark - Output UIImage

- (UIImage *)drawOnImage:(UIImage *)image
{
    [self.movableView cancelEditing];
    UIImage *drawImage;
    if (!image) {
        drawImage = self.gridView.hidden ? nil : [self.gridView drawImage];
        drawImage = [self.movableView renderImageOnImage:drawImage];
        drawImage = [self.drawView drawOnImage:drawImage];
    } else {
        drawImage = [self.drawView drawOnImage:image];
    }
    return drawImage;
//    return [self.textView drawTextOnImage:drawImage];
}

- (UIImage *)renderImage
{
    return [self renderImageWithScale:1.f];
}

- (UIImage *)renderImageOnColor:(UIColor *)color
{
    return [self renderImageWithScale:1.f onColor:color];
}

- (UIImage *)renderImageWithScale:(CGFloat)scale
{
    return [self renderImageWithSize:CGSizeMake(CGRectGetWidth(self.drawingContainer.frame) * scale,
                                           CGRectGetHeight(self.drawingContainer.frame) * scale)];
}

- (UIImage *)renderImageWithScale:(CGFloat)scale onColor:(UIColor *)color
{
    return [self renderImageWithSize:CGSizeMake(CGRectGetWidth(self.drawingContainer.frame) * scale,
                                                CGRectGetHeight(self.drawingContainer.frame) * scale)
                             onColor:color];
}

- (UIImage *)renderImageWithSize:(CGSize)size
{
    [self.movableView cancelEditing];
    UIImage *renderDrawingImage = [self.drawView renderDrawingWithSize:size];
    return renderDrawingImage;
//    return [self.textView drawTextOnImage:renderDrawingImage];
}

- (UIImage *)renderImageWithSize:(CGSize)size onColor:(UIColor *)color
{
    UIImage *colorImage = [UIImage jotImageWithColor:color size:size];
    UIImage *renderDrawingImage = [self.drawView drawOnImage:colorImage];
    return renderDrawingImage;
//    return [self.textView drawTextOnImage:renderDrawingImage];
}

#pragma mark - Gestures

- (void)handleTapGesture:(UIGestureRecognizer *)recognizer
{
    switch (self.state) {
        case JotViewStateImage:
            self.state = JotViewStateDrawing;
            break;
        case JotViewStateText: {
            JotMovableView *view = [self.movableView handleTapGesture:(UITapGestureRecognizer*)recognizer];
            self.state = !!view ? JotViewStateText : JotViewStateDrawing;
            break;
        }
        default:
            break;
    }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)recognizer
{
    switch (self.state) {
        case JotViewStateImage:
        case JotViewStateText:
            [self.movableView handlePanGesture:recognizer];
            break;
        default:
            break;
    }
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer*)recognizer {
    switch (self.state) {
        case JotViewStateImage:
        case JotViewStateText:
            [self.movableView handlePinchGesture:(UIPinchGestureRecognizer*)recognizer];
            break;
        default:
            break;
    }
}

- (void) handleRotateGesture:(UIRotationGestureRecognizer*)recognizer {
    switch (self.state) {
        case JotViewStateImage:
        case JotViewStateText:
            [self.movableView handleRotateGesture:(UIRotationGestureRecognizer*)recognizer];
            break;
        default:
            break;
    }
}

- (void) handleLongPressGesture:(UILongPressGestureRecognizer*)recognizer {
    if (self.photosAdded) {
        
        JotMovableView *view = [self.movableView handleLongPressGesture:recognizer];
        if (view) {
            if (view.type == JotMovableViewContainerTypeImage) {
                self.state = JotViewStateImage;
            } else if (view.type == JotMovableViewContainerTypeText) {
                self.state = JotViewStateText;
            }
        }
    }
}

#pragma mark - JotDrawingContainer Delegate

- (void)jotDrawingContainerTouchBeganAtPoint:(CGPoint)touchPoint
{
    if (self.state == JotViewStateDrawing || self.state == JotViewStateStraightLineDrawing || self.state == JotViewStateErase) {
        [self.drawView drawTouchBeganAtPoint:touchPoint];
    }
    if ([self.delegate respondsToSelector:@selector(jotViewControllerDidBeginDrawing:)]) {
        [self.delegate jotViewControllerDidBeginDrawing:self];
    }
}

- (void)jotDrawingContainerTouchMovedToPoint:(CGPoint)touchPoint
{
    switch (self.state) {
        case JotViewStateDrawing:
        case JotViewStateStraightLineDrawing:
        case JotViewStateErase:
            [self.drawView drawTouchMovedToPoint:touchPoint];
            break;
        default:
            break;
    }
}

- (void)jotDrawingContainerTouchEnded
{
    [self.viewsInEditOrder addObject:self.drawView];
    if (self.state == JotViewStateDrawing || self.state == JotViewStateStraightLineDrawing || self.state == JotViewStateErase) {
        [self.drawView drawTouchEnded];
    }
    if ([self.delegate respondsToSelector:@selector(jotViewControllerDidEndDrawing:)]) {
        [self.delegate jotViewControllerDidEndDrawing:self];
    }
}

#pragma mark - UIGestureRecognizer Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

#pragma mark - JotTextEditView Delegate

- (void)jotTextEditViewFinishedEditingWithNewTextString:(NSString *)textString
{
    if (self.state == JotViewStateEditingText) {
        self.state = JotViewStateText;
    }
    
    self.textString = textString;
    
    if ([self.delegate respondsToSelector:@selector(jotViewController:isEditingText:)]) {
        [self.delegate jotViewController:self isEditingText:NO];
    }
}

#pragma mark - JotImageViewDelegate

- (void) jotMovableViewContainerUndoSnapshot:(JotMovableViewContainer *)jotImageView {
    [self.viewsInEditOrder addObject:jotImageView];
}

#pragma mark - Setters & Getters

- (NSMutableArray<__kindof UIView*> *)viewsInEditOrder {
    if (!_viewsInEditOrder) {
        _viewsInEditOrder = [NSMutableArray new];
    }
    return _viewsInEditOrder;
}

@end

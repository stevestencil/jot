//
//  JotImageViewContainer.m
//  Pods
//
//  Created by Steve Stencil on 4/29/20.
//

#import "JotMovableView.h"
#import "Masonry.h"

static CGFloat const kEditAnimationDuration = 0.3f;

@interface JotMovableView () <UITextFieldDelegate>

@property (nonatomic) CGFloat aspectRatio;
@property (strong, nonatomic) NSMutableArray<NSDictionary*> *editHistory;
@property (weak, nonatomic, readonly) UIImageView *imageView;
@property (weak, nonatomic, readonly) UITextField *textLabel;
// font size relative to width of superview
@property (nonatomic) CGFloat originalFontSizeRatio;
@property (nonatomic) CGFloat currentFontSizeRatio;
@property (strong, nonatomic) NSDictionary *lastState;

@end

@implementation JotMovableView

+ (instancetype) movableViewWithImage:(UIImage*)image {
    JotMovableView *container = [JotMovableView new];
    [container addImageViewWithImage:image];
    container.backgroundColor = [UIColor clearColor];
    container.aspectRatio = image.size.width / image.size.height;
    return container;
}

+ (instancetype) movableViewWithText:(NSString*)text {
    JotMovableView *container = [JotMovableView new];
    [container addTextLabelWithText:text];
    return container;
}

- (instancetype) init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceRotated) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) addImageViewWithImage:(UIImage*)image {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    [self addSubview:imageView];
    _imageView = imageView;
    _type = JotMovableViewContainerTypeImage;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.userInteractionEnabled = NO;
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.mas_width);
        make.height.equalTo(self.mas_height);
        make.center.equalTo(self);
    }];
}

- (void) addTextLabelWithText:(NSString*)text {
    UITextField *label = [[UITextField alloc] init];
    label.returnKeyType = UIReturnKeyDone;
    label.font = [label.font fontWithSize:50.0];
    label.userInteractionEnabled = NO;
    label.text = text;
    [label sizeToFit];
    label.delegate = self;
    [self addSubview:label];
    _textLabel = label;
    _type = JotMovableViewContainerTypeText;
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.mas_width);
        make.height.equalTo(self.mas_height);
        make.center.equalTo(self);
    }];
}

- (NSAttributedString *)attributedString {
    return self.textLabel.attributedText;
}

#pragma mark - Layout

- (void) deviceRotated {
    if (self.type == JotMovableViewContainerTypeText) {
        CGFloat fontSize = self.superview.frame.size.width * self.currentFontSizeRatio;
        self.textLabel.font = [self.textLabel.font fontWithSize:fontSize];
        [self.textLabel sizeToFit];
        [self updateConstraintsForSize:self.textLabel.frame.size center:self.center];
    }
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    self.center = self.superview.center;
    self.originalFontSizeRatio = self.textLabel.font.pointSize / self.superview.frame.size.width;
    self.currentFontSizeRatio = self.originalFontSizeRatio;
}

#pragma mark - Undo

- (NSDictionary*) currentState {
    return @{
        @"size": [NSValue valueWithCGSize:self.frame.size],
        @"center": [NSValue valueWithCGPoint:self.center],
        @"transform": [NSValue valueWithCGAffineTransform:self.transform],
        @"text": self.textLabel.text ? : @""
    };
}

- (void) captureUndoObject {
    NSDictionary *currentState = [self currentState];
    [self.editHistory addObject:currentState];
}

- (void) restorePositionFromState:(NSDictionary*)state {
    if (state) {
        CGSize size = [state[@"size"] CGSizeValue];
        CGPoint center = [state[@"center"] CGPointValue];
        [self updateConstraintsForSize:size center:center];
        CGAffineTransform transform = [state[@"transform"] CGAffineTransformValue];
        self.transform = transform;
        self.textLabel.text = state[@"text"];
    }
}

- (instancetype) undo {
    NSDictionary *lastCapture = [self.editHistory lastObject];
    if (!lastCapture) {
        [self removeFromSuperview];
        return nil;
    }
    [self restorePositionFromState:lastCapture];
    [self.editHistory removeLastObject];
    return self;
}

#pragma mark - Moving, Resizing and Rotation

- (void) updateConstraintsForSize:(CGSize)size center:(CGPoint)center {
    [self mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (self.type == JotMovableViewContainerTypeImage) {
            CGFloat widthPercentage = MAX(0.15f, floorf((size.width / CGRectGetWidth(self.superview.frame)) * 100) / 100);
            make.width.equalTo(self.superview.mas_width).multipliedBy(MAX(0.15f, widthPercentage));
            make.height.equalTo(self.mas_width).dividedBy(self.aspectRatio);
        }
        make.centerX.equalTo(self.superview.mas_right).multipliedBy(center.x / CGRectGetWidth(self.superview.frame));
        make.centerY.equalTo(self.superview.mas_bottom).multipliedBy(center.y / CGRectGetHeight(self.superview.frame));
    }];
}

- (void) resizeWithScale:(CGFloat)scale moveToCenter:(CGPoint)center {
    if (self.type == JotMovableViewContainerTypeImage) {
        CGSize newSize = CGSizeMake(self.superview.frame.size.width, self.superview.frame.size.width / self.aspectRatio);
        if (newSize.height > self.superview.frame.size.height) {
            newSize.height = self.superview.frame.size.height;
            newSize.width = self.superview.frame.size.height * self.aspectRatio;
        }
        newSize = CGSizeMake(newSize.width * scale, newSize.height * scale);
        [self updateConstraintsForSize:newSize center:center];
    } else if (self.type == JotMovableViewContainerTypeText) {
        CGFloat fontSize = (self.originalFontSizeRatio * self.superview.frame.size.width) * scale;
        self.currentFontSizeRatio = fontSize / self.superview.frame.size.width;
        self.textLabel.font = [self.textLabel.font fontWithSize:fontSize];
        [self.textLabel sizeToFit];
        [self updateConstraintsForSize:self.textLabel.frame.size center:center];
    }
}

- (void) resizeWithSize:(CGSize)size {
    [self updateConstraintsForSize:size center:self.center];
}

- (void)resizeWithScale:(CGFloat)scale {
    [self resizeWithScale:scale moveToCenter:self.center];
}

- (void) moveViewToCenter:(CGPoint)center {
    [self updateConstraintsForSize:self.frame.size center:center];
}

- (void) resizeWithSize:(CGSize)size moveToCenter:(CGPoint)center {
    [self updateConstraintsForSize:size center:center];
}

- (void)setTransform:(CGAffineTransform)transform {
    CGFloat angle = RADIANS_TO_DEGREES(atan2f(transform.b, transform.a));
    if (angle >= -5 && angle <= 5) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(0));
    } else if (angle >= 85 && angle <= 95) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(90));
    } else if (angle >= -95 && angle <= -85) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-90));
    } else if ((angle >= 175 && angle <= 185)) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(180));
    } else if (angle >= -185 && angle <= -175) {
        transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-180));
    }
    self.imageView.transform = transform;
    self.textLabel.transform = transform;
}

- (CGAffineTransform)transform {
    return self.imageView ? self.imageView.transform : self.textLabel.transform;
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.lastState = [self currentState];
    [self.superview layoutIfNeeded];
    _isEditing = YES;
    if ([self.delegate respondsToSelector:@selector(jotMovableView:didBeginUpdateText:)]) {
        [self.delegate jotMovableView:self didBeginUpdateText:self.textLabel.text];
    }
    [UIView animateWithDuration:kEditAnimationDuration animations:^{
        [self mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.superview.mas_top);
            make.leading.equalTo(self.superview.mas_leading);
            make.trailing.equalTo(self.superview.mas_trailing);
        }];
        self.transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(0));
        [self.superview layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self.textLabel selectAll:nil];
    }];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    _isEditing = NO;
    [self.superview layoutIfNeeded];
    [UIView animateWithDuration:kEditAnimationDuration animations:^{
        NSMutableDictionary *state = [self.lastState mutableCopy];
        state[@"text"] = self.textLabel.text ? : @"";
        [self restorePositionFromState:state];
        self.lastState = nil;
        [self.superview layoutIfNeeded];
    } completion:^(BOOL finished) {
        if ([self.delegate respondsToSelector:@selector(jotMovableView:didEndUpdateText:)]) {
            [self.delegate jotMovableView:self didEndUpdateText:self.textLabel.text];
        }
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Setters & Getters

- (void) setSelected:(BOOL)selected {
    if (!selected) {
        self.imageView.layer.borderWidth = 0.0;
    } else {
        self.imageView.layer.borderWidth = 2.0;
        self.imageView.layer.borderColor = [[UIColor yellowColor] CGColor];
    }
}

- (NSMutableArray<NSDictionary *> *)editHistory {
    if (!_editHistory) {
        _editHistory = [NSMutableArray new];
    }
    return _editHistory;
}

- (UIImage *)image {
    return self.imageView.image;
}

- (void)setFontColor:(UIColor *)color {
    self.textLabel.textColor = color;
}

- (void)setIsEditing:(BOOL)isEditing {
    _isEditing = isEditing;
    if (isEditing) {
        self.textLabel.userInteractionEnabled = YES;
        [self.textLabel becomeFirstResponder];
    } else {
        [self.textLabel resignFirstResponder];
        self.textLabel.userInteractionEnabled = NO;
    }
}

@end

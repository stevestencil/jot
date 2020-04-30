//
//  JotImageViewContainer.m
//  Pods
//
//  Created by Steve Stencil on 4/29/20.
//

#import "JotImageViewContainer.h"
#import "Masonry.h"

@implementation JotImageViewContainer

+ (instancetype) imageViewContainerWithImage:(UIImage*)image {
    JotImageViewContainer *container = [JotImageViewContainer new];
    [container addImageViewWithImage:image];
    container.backgroundColor = [UIColor orangeColor];
    container.scale = 1.0f;
    return container;
}

- (void) addImageViewWithImage:(UIImage*)image {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    [self addSubview:imageView];
    _imageView = imageView;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.userInteractionEnabled = NO;
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.mas_width);
        make.height.equalTo(self.mas_height);
        make.center.equalTo(self);
    }];
}

- (void) layoutSubviews {
    [super layoutSubviews];
}

- (void)setTransform:(CGAffineTransform)transform {
    self.imageView.transform = transform;
}

- (CGAffineTransform)transform {
    return self.imageView.transform;
}

@end

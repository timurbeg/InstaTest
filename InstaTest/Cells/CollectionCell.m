//
//  SBInstagramCell.m
//  instagram
//
//  Created by Santiago Bustamante on 8/31/13.
//  Copyright (c) 2013 Pineapple Inc. All rights reserved.
//

#import "CollectionCell.h"

@implementation CollectionCell

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {

    }
    return self;
}

- (void)setMedia:(InstagramMedia *)media andIndexPath:(NSIndexPath *)index {

    _media = media;
    
    [self setupCell];
    
    NSURL *imageURL = _media.thumbnailURL;
    if (_media.thumbnailFrameSize.width <= CGRectGetWidth(_imageView.frame)) {
        imageURL = _media.lowResolutionImageURL;
    }
    if (_media.lowResolutionImageFrameSize.width <= CGRectGetWidth(_imageView.frame)) {
        imageURL = _media.standardResolutionImageURL;
    }
    
    [[InstagramEngine sharedEngine] downloadImageWithUrl:imageURL
                                                andBlock:^(UIImage *image, NSError *error) {
                                                    if (self.indexPath.row == index.row) {
                                                        [_imageView setImage:image];
                                                    }
                                                }

                                           progressBlock:^(float progress) {
                                           }];
}

- (void)setupCell {

    [[self.contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
        [_imageView setBackgroundColor:[UIColor lightGrayColor]];
        [_imageView setContentMode:UIViewContentModeScaleAspectFit];
        
    }
    [_imageView setFrame:CGRectMake(0.f, 0.f, self.frame.size.width, self.frame.size.width)];
    [_imageView setUserInteractionEnabled:YES];
    [_imageView setImage:nil];
    
    [self.contentView addSubview:_imageView];

    
}


- (void)dealloc {
    

}


@end

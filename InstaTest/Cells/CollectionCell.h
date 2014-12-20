//
//  SBInstagramCell.h
//  instagram
//
//  Created by Santiago Bustamante on 8/31/13.
//  Copyright (c) 2013 Pineapple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InstagramMedia.h"

@interface CollectionCell : UICollectionViewCell


@property (strong, nonatomic) UIImageView *imageView;
@property (assign, nonatomic) InstagramMedia *media;
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, assign) BOOL showOnePicturePerRow;

- (void)setMedia:(InstagramMedia *)media andIndexPath:(NSIndexPath *)index;

@end

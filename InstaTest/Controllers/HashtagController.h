//
//  PopularMediaController.h
//  Raminstag
//
//  Created by Timur on 18/12/14.
//  Copyright (c) 2014 TimCo. All rights reserved.
//

#import "BaseViewController.h"
#import "PopoverView.h"

@interface HashtagController : BaseViewController <UICollectionViewDelegate, UICollectionViewDataSource, PopoverViewDelegate, UISearchBarDelegate> {
    
    UICollectionView *_collectionView;
    FeedType _feedType;
    
    UIBarButtonItem *_rightBtnItem;
    PopoverView *_popover;
    InstagramPaginationInfo *_paginationInfo;
}

@property (nonatomic, strong) UIView *headerView;


@end

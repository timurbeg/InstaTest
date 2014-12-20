//
//  InfiniteScrollController.m
//  InstaTest
//
//  Created by Timur on 18/12/14.
//  Copyright (c) 2014 TimCo. All rights reserved.
//

#import "InfiniteScrollController.h"
#import "UIImageView+AFNetworking.h"
#import "KTPhotoView.h"

@implementation InfiniteScrollController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Infinite scroll (Zoom)";
    
    UIBarButtonItem *dismissItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismiss:)];
    self.navigationItem.leftBarButtonItem = dismissItem;

    CGRect rect = CGRectMake(0.f, 0.f, kPortraitWidth, kPortraitHeight);
    
    InfinitePagingView *infiniteScroll = [[InfinitePagingView alloc] initWithFrame:rect andDataSource:self];
    [self.view addSubview:infiniteScroll];
}

- (void)dismiss:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma InfinitePagingView DataSource methods

- (UIView*)infinitePagingView:(InfinitePagingView*)infinitePagingView viewForPageIndex:(NSInteger)index {
    
    InstagramMedia *media = _items[index];
    
    KTPhotoView *photoView = [[KTPhotoView alloc] init];
    photoView.frame = CGRectMake(0.f, 0.f, kPortraitWidth, kPortraitHeight);
    [photoView.imageView setImageWithURL:media.standardResolutionImageURL placeholderImage:nil];
    
    return photoView;
}

- (NSInteger)itemsCount {
 
    return _items.count;
}

- (NSInteger)startIndex {
    
    return _currentIndex;
}


- (void)dealloc {
    
    NSLog(@"%@ released", [[self class] description]);
}


@end













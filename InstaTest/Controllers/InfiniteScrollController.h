//
//  InfiniteScrollController.h
//  InstaTest
//
//  Created by Timur on 18/12/14.
//  Copyright (c) 2014 TimCo. All rights reserved.
//
#import "InfinitePagingView.h"

@interface InfiniteScrollController : UIViewController <InfinitePagingDataSource>

@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, assign) NSUInteger currentIndex;

@end

//
//  InfinitePagingView.h
//  InfinitePaging
//
//  Created by Timur on 19/12/14.
//  Copyright (c) 2014 TimCo. All rights reserved.
//

#import <UIKit/UIKit.h>

@class InfinitePagingView;

// Protocol to define methods for a data souce delegate
@protocol InfinitePagingDataSource

@required

- (UIView*)infinitePagingView:(InfinitePagingView*)infinitePagingView viewForPageIndex:(NSInteger)index;
- (NSInteger)itemsCount;
- (NSInteger)startIndex;

@end


// Interface definition.
@interface InfinitePagingView : UIView <UIScrollViewDelegate> {
	
//	__unsafe_unretained id<InfinitePagingDataSource> dataSource;	//data source delegate
	
	UIScrollView		*scrollView;		//internal scroll view
	NSMutableDictionary	*viewBuffer;		//temporary view buffer
	NSInteger           pageIndex;			//current page index
	NSInteger           startIndex;
}

@property(nonatomic, assign) __unsafe_unretained id<InfinitePagingDataSource> dataSource;

- (id)initWithFrame:(CGRect)frame andDataSource:(id<InfinitePagingDataSource>) ds;

@end

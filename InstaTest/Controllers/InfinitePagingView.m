//
//  InfinitePagingView.m
//  InfinitePaging
//
//  Created by Timur on 19/12/14.
//  Copyright (c) 2014 TimCo. All rights reserved.
//

#import "InfinitePagingView.h"

#define MAX_BUFFER_SIZE 6

@interface InfinitePagingView()

- (void) setup;
- (void) updateToPage:(NSInteger) page;
- (void) setViewForPage:(NSInteger) page;
- (void) checkViewBuffer;

@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) NSMutableDictionary *viewBuffer;
@property(nonatomic, assign) NSInteger startIndex;

@end

@implementation InfinitePagingView

@synthesize dataSource;
@synthesize scrollView;
@synthesize viewBuffer;
@synthesize startIndex;

// Do the intial setup of the infinite paging view.
- (void)setup
{
	//init page index
	pageIndex = -1;

	//init view buffer
	viewBuffer = [[NSMutableDictionary alloc] init];

	//setup view
	self.backgroundColor = [UIColor clearColor];
	
	//init scroll view
	self.scrollView = [[UIScrollView alloc] initWithFrame:self.frame];
	scrollView.backgroundColor = [UIColor clearColor];
	scrollView.pagingEnabled = YES;
	scrollView.delegate = self;
	scrollView.alwaysBounceHorizontal = NO;
	scrollView.directionalLockEnabled = YES;
	scrollView.showsHorizontalScrollIndicator = NO;
	self.scrollView.contentInset = UIEdgeInsetsMake(-64.f, 0.f, 0.f, 0.f);
    
	//add scroll view
	[self addSubview:scrollView];
	
	//initialize first pages
	NSInteger start = [dataSource startIndex];
	[self updateToPage:start];
	
	CGRect viewFrame = scrollView.frame;
	viewFrame.origin.x = start * scrollView.frame.size.width;
	[scrollView scrollRectToVisible:viewFrame animated:YES];
}

// Update to new page. This occurs when the user
// scrolls the view to a new page.
- (void) updateToPage:(NSInteger) page
{
    NSInteger itemsCount = [dataSource itemsCount];
    BOOL isLastPage = (page + 1 == itemsCount);
    
	if (page != pageIndex && page < itemsCount)
	{
		CGFloat pageWidth	= scrollView.frame.size.width;
        CGSize	size        = scrollView.frame.size;
        size.height         -= (kBarPortraitHeight + kStatusBarHeight);
        CGSize	contentSize	= size;
		
        int nextPagesCount  = isLastPage ? 1 : 2;
		contentSize.width   = pageWidth * (page + nextPagesCount);

		[self setViewForPage:(page-1)];
		[self setViewForPage:page];
        if (!isLastPage)
            [self setViewForPage:(page+1)];

		self.scrollView.contentSize = contentSize;
		pageIndex = page;
	}
}

// Load the view for a given page. Use the dataSource
// to get the view or check the view buffer.
- (void) setViewForPage:(NSInteger) page
{
	if (page < 0)
		return;

	//calculate x offset
	CGFloat offsetX	= scrollView.frame.size.width * page;
	
	//check if view is allready within the view buffer
	UIView *view = nil;
	if ((view = [self.viewBuffer objectForKey:[NSNumber numberWithInteger:page]]) == nil)
	{
		//get view from data source
		view = [self.dataSource infinitePagingView:self viewForPageIndex:page];
		[self.viewBuffer setObject:view forKey:[NSNumber numberWithInteger:page]];
		
		//set the x offset
		CGRect viewFrame = view.frame;
		viewFrame.origin.x = offsetX;
		view.frame = viewFrame;
		
		//add as subview
		[self.scrollView addSubview:view];
		
		//check view buffer size
		[self checkViewBuffer];
	}
}

// Check if view buffer violates the max. view
// buffer size and clean it up if necessary.
- (void) checkViewBuffer
{
	if (self.viewBuffer && [self.viewBuffer count] > MAX_BUFFER_SIZE)
	{
		for (NSNumber *page in [self.viewBuffer allKeys])
		{
			if ([page intValue] < (pageIndex - 2) || [page intValue] > (pageIndex + 2))
			{
				UIView *view = [self.viewBuffer objectForKey:page];
                [view removeFromSuperview];
				[self.viewBuffer removeObjectForKey:page];
			}
		}
	}
}


#pragma mark -
#pragma mark UIScrollViewDelegate methods

// Notification about any scroll offset change.
- (void)scrollViewDidScroll:(UIScrollView *)sView
{
    CGFloat pageWidth = sView.frame.size.width;
	int page = floor((sView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
	[self updateToPage:page];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)sView {

}

#pragma mark -
#pragma mark Initialization and memory management

// Initialize the view with given frame and data source.

- (id)initWithFrame:(CGRect)frame andDataSource:(id<InfinitePagingDataSource>) ds
{
    if ((self = [super initWithFrame:frame])) {
		self.dataSource = ds;
		[self setup];
	}
    return self;
}


- (void)dealloc {

    NSLog(@"%@ released", [[self class] description]);
}


@end

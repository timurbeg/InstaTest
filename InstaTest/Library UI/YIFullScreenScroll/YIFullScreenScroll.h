//
//  YIFullScreenScroll.h
//  YIFullScreenScroll
//
//  Created by Yasuhiro Inami on 12/06/03.
//  Copyright (c) 2012 Yasuhiro Inami. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIViewController+YIFullScreenScroll.h"

@protocol YIFullScreenScrollDelegate;

typedef NS_ENUM(NSInteger, YIFullScreenScrollStyle) {
    YIFullScreenScrollStyleDefault,     // no statusBar-background when navBar is hidden
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    YIFullScreenScrollStyleFacebook,    // like facebook ver 6.0, remaining navBar for statusBar-background in iOS7
#endif
};

//
// NOTE:
// YIFullScreenScroll forces viewController.navigationController's navigationBar/toolbar
// to set translucent=YES (to set navigationController's content size wider for convenience),
// and sets custom background imageView to make it opaque again.
//
@interface YIFullScreenScroll : NSObject

@property (nonatomic, weak) id <YIFullScreenScrollDelegate> delegate;

@property (nonatomic, weak) UIViewController* viewController;
@property (nonatomic, strong) UIScrollView* scrollView;
@property (nonatomic, strong) UINavigationBar* navigationBar;


@property (nonatomic) YIFullScreenScrollStyle style;

@property (nonatomic) BOOL enabled;                 // default = YES
@property (nonatomic) BOOL layoutingUIBarsEnabled;  // can pause layouting UI-bars, default = YES

@property (nonatomic) BOOL shouldShowUIBarsOnScrollUp;      // default = YES

@property (nonatomic) BOOL shouldHideNavigationBarOnScroll; // default = YES
@property (nonatomic) BOOL shouldHideToolbarOnScroll;       // default = YES
@property (nonatomic) BOOL shouldHideTabBarOnScroll;        // default = YES

@property (nonatomic) BOOL shouldHideUIBarsGradually;       // default = YES

// if YES, UI-bars can also be hidden via UIWebView's JavaScript calling window.scrollTo(0,1))
@property (nonatomic) BOOL shouldHideUIBarsWhenNotDragging;             // default = NO

@property (nonatomic) BOOL shouldHideUIBarsWhenContentHeightIsTooShort; // default = NO

// offsetY for start hiding & showing back again on top
@property (nonatomic) CGFloat additionalOffsetYToStartHiding;   // default = 0.0
@property (nonatomic) CGFloat additionalOffsetYToStartShowing;  // default = 0.0, will be adjusted on every setStyle

@property (nonatomic) CGFloat showHideAnimationDuration;    // default = 0.1

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView;

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView
                       style:(YIFullScreenScrollStyle)style;

- (void)showUIBarsAnimated:(BOOL)animated;
- (void)showUIBarsAnimated:(BOOL)animated completion:(void (^)(BOOL finished))completion;

- (void)hideUIBarsAnimated:(BOOL)animated;
- (void)hideUIBarsAnimated:(BOOL)animated completion:(void (^)(BOOL finished))completion;

// If you are using UISearchDisplayController in iOS7, call this on '-searchBarShouldBeginEditing:'.
// This will prevent from searchBar not responding touches
// when you slightly scrolled down (about searchBar height) and then activate searchDisplayController.
// (Implementing in '-searchDisplayControllerWillBeginSearch:' doesn't work)
// 
- (void)adjustScrollPositionWhenSearchDisplayControllerBecomeActive;
- (void)autoScrolling;

@end


// used in UIViewController+YIFullScreenScroll
@interface YIFullScreenScroll (ViewLifecycle)

- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration;

@end


@protocol YIFullScreenScrollDelegate <NSObject>

@optional

//
// Use this method to layout your custom views after
// default UI-bars (navigationBar/toolbar/tabBar) are set.
//
// NOTE:
// This method is different from UIScrollViewDelegate's '-scrollViewDidScroll:'
// which will be called on next run-loop after contentOffset is observed & layout is triggered.
// This means that default UI-bars & your custom views may not layout synchronously
// if you use '-scrollViewDidScroll:'.
//
- (void)fullScreenScrollDidLayoutUIBars:(YIFullScreenScroll*)fullScreenScroll;

@end


@protocol YIFullScreenScrollNoFading
@end

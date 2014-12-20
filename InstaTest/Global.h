//
//  Global.h
//
//  Created by Timur Begaliev on 12/18/14.
//  Copyright (c) 2014 Timur Begaliev. All rights reserved.
//

#import <Foundation/Foundation.h>

#define IS_WIDESCREEN   (fabs((double)[[UIScreen mainScreen] bounds].size.height - (double)568) < DBL_EPSILON)
#define IS_IPHONE       ([[[UIDevice currentDevice] model] hasPrefix: @"iPhone"])
#define IS_IPOD         ([[[UIDevice currentDevice] model] isEqualToString: @"iPod touch"])
#define IS_IPHONE_5     (IS_IPHONE && IS_WIDESCREEN)
#define IS_IOS_7        ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)

#define kPortraitHeight_IOS_7       CGRectGetHeight([[UIScreen mainScreen] bounds])
#define kPortraitHeight_IOS_6_5     ((IS_IPHONE_5 ? 568 : 480))
#define kPortraitHeight             (IS_IOS_7 ? kPortraitHeight_IOS_7 : kPortraitHeight_IOS_6_5)
#define kPortraitWidth              CGRectGetWidth([[UIScreen mainScreen] bounds])
#define kBarPortraitHeight 44
#define kTabBarHeight 48
#define kStatusBarHeight 20
#define kKeyboardHeightPortrait 216

#define SCREEN  [[[UIApplication sharedApplication] delegate] window]

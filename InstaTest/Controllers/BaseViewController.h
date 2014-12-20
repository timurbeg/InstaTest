//
//  BaseViewController.h
//  Raminstag
//
//  Created by Timur on 18/12/14.
//  Copyright (c) 2014 TimCo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "YIFullScreenScroll.h"
#import "AppDelegate.h"

typedef enum {
    
    FeedTypeTable = 1,
    FeedTypeGridx2,
    FeedTypeGridx3
    
} FeedType;

@interface BaseViewController : UIViewController <YIFullScreenScrollDelegate> {

}

- (void)performBlock:(dispatch_block_t)block afterDelay:(int)interval;


@end

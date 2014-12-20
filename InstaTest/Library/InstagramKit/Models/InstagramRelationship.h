//
//  InstagramRelationship.h
//  Raminstag
//
//  Created by Timur on 18/12/14.
//  Copyright (c) 2014 TimCo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface InstagramRelationship : NSObject

@property (readonly) NSString *outgoingStatus;
@property (readonly) NSString *incomingStatus;
@property (readonly) BOOL isPrivateUser;

- (BOOL)amIFollowing;
- (BOOL)didIRequest;
- (BOOL)amINotFollowing;

- (BOOL)wasIFollowed;
- (BOOL)wasIRequested;
- (BOOL)didIBlock;
- (BOOL)wasNotIFollowed;

- (void)updateWithInfo:(NSDictionary *)info;

@end

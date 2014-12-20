//
//  InstagramRelationship.m
//  Raminstag
//
//  Created by Timur on 18/12/14.
//  Copyright (c) 2014 TimCo. All rights reserved.
//

#import "InstagramRelationship.h"
#import "InstagramModel.h"

@implementation InstagramRelationship

- (id)initWithInfo:(NSDictionary *)info
{
    self = [super init];
    if (self && IKNotNull(info)) {

        //outgoing_status: Your relationship to the user. Can be "follows", "requested", "none".
        //incoming_status: A user's relationship to you. Can be "followed_by", "requested_by", "blocked_by_you", "none".

        _outgoingStatus = info[kOutgoingStatus];
        _incomingStatus = info[kIncomingStatus];
        _isPrivateUser = [info[kTargetUserIsPrivate] boolValue];

    }
    return self;
}

- (void)updateWithInfo:(NSDictionary *)info {

    if (info[kOutgoingStatus]) {
        _outgoingStatus = info[kOutgoingStatus];
    }

    if (info[kIncomingStatus]) {
        _incomingStatus = info[kIncomingStatus];
    }

    if (info[kTargetUserIsPrivate]) {
        _isPrivateUser = [info[kTargetUserIsPrivate] boolValue];
    }
    
}

- (BOOL)amIFollowing {
    
    return [_outgoingStatus isEqualToString:@"follows"];
}

- (BOOL)didIRequest {
    
    return [_outgoingStatus isEqualToString:@"requested"];
}

- (BOOL)amINotFollowing {
    
    return [_outgoingStatus isEqualToString:@"none"];
}

- (BOOL)wasIFollowed {
    
    return [_incomingStatus isEqualToString:@"followed_by"];
}

- (BOOL)wasIRequested {
    
    return [_incomingStatus isEqualToString:@"requested_by"];
}

- (BOOL)didIBlock {
    
    return [_incomingStatus isEqualToString:@"blocked_by_you"];
}

- (BOOL)wasNotIFollowed {
    
    return [_incomingStatus isEqualToString:@"none"];
}


@end

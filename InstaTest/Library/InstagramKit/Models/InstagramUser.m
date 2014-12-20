//
//    Copyright (c) 2013 Shyam Bhat
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy of
//    this software and associated documentation files (the "Software"), to deal in
//    the Software without restriction, including without limitation the rights to
//    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//    the Software, and to permit persons to whom the Software is furnished to do so,
//    subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "InstagramUser.h"
#import "InstagramEngine.h"

@interface InstagramUser()

@end

@implementation InstagramUser

- (id)initWithInfo:(NSDictionary *)info
{
    self = [super initWithInfo:info];
    if (self && IKNotNull(info)) {
        _username = [[NSString alloc] initWithString:info[kUsername]];
        _fullName = [[NSString alloc] initWithString:info[kFullName]];
        _profilePictureURL = [[NSURL alloc] initWithString:info[kProfilePictureURL]];
        if (IKNotNull(info[kBio]) && [info[kBio] length] != 0)
            _bio = [[NSString alloc] initWithString:info[kBio]];;
        if (IKNotNull(info[kWebsite]) && [info[kWebsite] length] != 0)
            _website = [[NSURL alloc] initWithString:info[kWebsite]];
        // DO NOT PERSIST
        if (IKNotNull(info[kCounts]))
        {
            _mediaCount = [(info[kCounts])[kCountMedia] integerValue];
            _followsCount = [(info[kCounts])[kCountFollows] integerValue];
            _followedByCount = [(info[kCounts])[kCountFollowedBy] integerValue];
        }
    }
    return self;
}

- (NSString *)infoString {
    
    NSMutableString *bioText = [[NSMutableString alloc] initWithCapacity:0];
    if ([_bio length]) {
        [bioText appendString:_bio];
    }
    if (_website && [[_website absoluteString] length]) {
        [bioText appendFormat:@"%@%@", [bioText length] > 0 ? @"\n" : @"",[_website absoluteString]];
    }
    return bioText;
}

- (void)loadUserInfoWithSuccess:(void(^)(void))success failure:(void(^)(void))failure
{
    [[InstagramEngine sharedEngine] getUserDetails:self withSuccess:^(InstagramUser *userDetail) {
        _mediaCount = userDetail.mediaCount;
        _followsCount = userDetail.followsCount;
        _followedByCount = userDetail.followedByCount;
        _bio = userDetail.bio;
        _website = userDetail.website;
        
        [[InstagramEngine sharedEngine] getRelationshipForUser:self.Id withSuccess:^(InstagramRelationship *relationship) {
            _relationship = relationship;
            success();
        } failure:^(NSError *error) {
            DLog(@"%@", [error description]);
            failure();
        }];
        
        
    } failure:^(NSError *error) {

        [[InstagramEngine sharedEngine] getRelationshipForUser:self.Id withSuccess:^(InstagramRelationship *relationship) {
            _relationship = relationship;
            failure();
        } failure:^(NSError *error) {
            DLog(@"%@", [error description]);
            failure();
        }];
    }];
}

@end

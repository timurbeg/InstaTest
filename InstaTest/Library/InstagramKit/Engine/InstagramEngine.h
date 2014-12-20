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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "AFNetworking.h"
    
@class InstagramUser;
@class InstagramMedia;
@class InstagramPaginationInfo;
@class InstagramTag;
@class InstagramRelationship;

typedef void (^InstagramLoginBlock)(NSError* error);
typedef void (^InstagramObjectBlock)(id response);
typedef void (^InstagramMediaBlock)(NSArray *media, InstagramPaginationInfo *paginationInfo);
typedef void (^InstagramUsersBlock)(NSArray *users, InstagramPaginationInfo *paginationInfo);
typedef void (^InstagramRelationshipBlock)(InstagramRelationship *relationship);
typedef void (^InstagramFailureBlock)(NSError* error);
typedef void (^InstagramTagsBlock)(NSArray *tags, InstagramPaginationInfo *paginationInfo);
typedef void (^InstagramCommentsBlock)(NSArray *comments);

extern NSString *const kKeyClientID;
extern NSString *const kKeyAccessToken;

extern NSString *const kInstagramKitAppClientIdConfigurationKey;
extern NSString *const kInstagramKitAppRedirectUrlConfigurationKey;

extern NSString *const kInstagramKitBaseUrlConfigurationKey;
extern NSString *const kInstagramKitAuthorizationUrlConfigurationKey;

// Head over to http://instagram.com/developer/clients/manage/ to find these.

extern NSString *const kInstagramKitErrorDomain;

typedef enum
{
    kInstagramKitErrorCodeNone,
    kInstagramKitErrorCodeAccessNotGranted,
    kInstagramKitErrorCodeUserCancelled = NSUserCancelledError,

} InstagramKitErrorCode;

@interface InstagramEngine : NSObject

+ (InstagramEngine *)sharedEngine;
+ (NSDictionary*)sharedEngineConfiguration;

@property (nonatomic, copy) NSString *appClientID;
@property (nonatomic, copy) NSString *appRedirectURL;
@property (nonatomic, copy) NSString *authorizationURL;


#pragma mark - Custom method -

- (NSString *)accessToken;

#pragma mark - Login -

- (void)loginWithBlock:(InstagramLoginBlock)block;

- (void)cancelLogin;

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            sourceApplication:(NSString *)
            sourceApplication
            annotation:(id)annotation;


#pragma mark - Auth -

- (void)checkAccesTokenWithBlock:(void (^)(NSError * error))block;

#pragma mark - Media -


- (void)getMedia:(NSString *)mediaId
     withSuccess:(void (^)(InstagramMedia *media))success
         failure:(InstagramFailureBlock)failure;


- (void)getPopularMediaWithSuccess:(InstagramMediaBlock)success
                           failure:(InstagramFailureBlock)failure;

#pragma mark -


- (void)getMediaAtLocation:(CLLocationCoordinate2D)location
               withSuccess:(InstagramMediaBlock)success
                   failure:(InstagramFailureBlock)failure;

- (void)getMediaAtLocation:(CLLocationCoordinate2D)location count:(NSInteger)count maxId:(NSString *)maxId
               withSuccess:(InstagramMediaBlock)success
                   failure:(InstagramFailureBlock)failure;



#pragma mark - Users -


- (void)getUserDetails:(InstagramUser *)user
           withSuccess:(void (^)(InstagramUser *userDetail))success
               failure:(InstagramFailureBlock)failure;

#pragma mark -


- (void)getMediaForUser:(NSString *)userId
        withSuccess:(InstagramMediaBlock)success
            failure:(InstagramFailureBlock)failure;

- (void)getMediaForUser:(NSString *)userId count:(NSInteger)count maxId:(NSString *)maxId
            withSuccess:(InstagramMediaBlock)success
                failure:(InstagramFailureBlock)failure;

#pragma mark -


- (void)searchUsersWithString:(NSString *)string
                  withSuccess:(InstagramUsersBlock)success
                      failure:(InstagramFailureBlock)failure;



#pragma mark - Self User -


- (void)getSelfUserDetailsWithSuccess:(void (^)(InstagramUser *userDetail))success
                              failure:(InstagramFailureBlock)failure;

#pragma mark -


- (void)getSelfFeedWithSuccess:(InstagramMediaBlock)success
            failure:(InstagramFailureBlock)failure;

- (void)getSelfFeedWithCount:(NSInteger)count maxId:(NSString *)maxId
        success:(InstagramMediaBlock)success
            failure:(InstagramFailureBlock)failure;

#pragma mark -


- (void)getMediaLikedBySelfWithSuccess:(InstagramMediaBlock)success
                        failure:(InstagramFailureBlock)failure;

- (void)getMediaLikedBySelfWithCount:(NSInteger)count maxId:(NSString *)maxId
                             success:(InstagramMediaBlock)success
                               failure:(InstagramFailureBlock)failure;


#pragma mark - Relations -

- (void)getFollowingsForUser:(NSString *)userId
                 withSuccess:(InstagramMediaBlock)success
                     failure:(InstagramFailureBlock)failure;

- (void)getFollowersForUser:(NSString *)userId
                withSuccess:(InstagramMediaBlock)success
                    failure:(InstagramFailureBlock)failure;

- (void)getRelationshipForUser:(NSString *)userId
                   withSuccess:(InstagramRelationshipBlock)success
                       failure:(InstagramFailureBlock)failure;

- (void)postRelationshipAction:(NSString *)action
                       forUser:(NSString *)userId
                   withSuccess:(InstagramObjectBlock)success
                       failure:(InstagramFailureBlock)failure;

#pragma mark - Tags -


- (void)getTagDetailsWithName:(NSString *)name
                  withSuccess:(void (^)(InstagramTag *tag))success
                      failure:(InstagramFailureBlock)failure;

#pragma mark -


- (void)getMediaWithTagName:(NSString *)tag
            withSuccess:(InstagramMediaBlock)success
                failure:(InstagramFailureBlock)failure;

- (void)getMediaWithTagName:(NSString *)tag count:(NSInteger)count maxId:(NSString *)maxId
                withSuccess:(InstagramMediaBlock)success
                    failure:(InstagramFailureBlock)failure;

#pragma mark -


- (void)searchTagsWithName:(NSString *)name
               withSuccess:(InstagramTagsBlock)success
                   failure:(InstagramFailureBlock)failure;

- (void)searchTagsWithName:(NSString *)name count:(NSInteger)count maxId:(NSString *)maxId
               withSuccess:(InstagramTagsBlock)success
                   failure:(InstagramFailureBlock)failure;



#pragma mark - Comments -


- (void)getCommentsOnMedia:(InstagramMedia *)media
               withSuccess:(InstagramCommentsBlock)success
                   failure:(InstagramFailureBlock)failure;

- (void)createComment:(NSString *)commentText
              onMedia:(InstagramMedia *)media
          withSuccess:(InstagramObjectBlock)success
              failure:(InstagramFailureBlock)failure;

- (void)removeComment:(NSString *)commentId
              onMedia:(InstagramMedia *)media
          withSuccess:(void (^)(void))success
              failure:(InstagramFailureBlock)failure;



#pragma mark - Likes -


- (void)getLikesOnMedia:(InstagramMedia *)media
            withSuccess:(void (^)(NSArray *likedUsers, InstagramPaginationInfo *paginationInfo))success
                failure:(InstagramFailureBlock)failure;

- (void)likeMedia:(InstagramMedia *)media
      withSuccess:(InstagramObjectBlock)success
          failure:(InstagramFailureBlock)failure;

- (void)unlikeMedia:(InstagramMedia *)media
        withSuccess:(void (^)(void))success
          failure:(InstagramFailureBlock)failure;



#pragma mark - Common Pagination Request -

- (void)getPaginatedItemsForInfo:(InstagramPaginationInfo *)paginationInfo
                     withSuccess:(InstagramMediaBlock)success
                         failure:(InstagramFailureBlock)failure;

#pragma mark - Downloading images

- (void)downloadImageWithUrl:(NSURL *)url andBlock:(void (^)(UIImage *image, NSError * error))block progressBlock:(void (^)(float progress))progressBlock;
- (void)downloadImageWithVideoUrl:(NSURL *)url andBlock:(void (^)(NSURL *filePathUrl, NSError *error))block progressBlock:(void (^)(float progress))progressBlock;
- (void)stopDownloadWithUrl:(NSString *)url;
- (AFHTTPRequestOperation *)operationWithUrl:(NSString *)url;

- (NSURL *)mediaCachePath:(NSURL *)url;

@end











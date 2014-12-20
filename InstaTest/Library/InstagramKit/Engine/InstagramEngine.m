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

#import "InstagramEngine.h"
#import "InstagramUser.h"
#import "InstagramMedia.h"
#import "InstagramComment.h"
#import "InstagramTag.h"
#import "InstagramPaginationInfo.h"
#import "InstagramRelationship.h"
#import "WebLoginController.h"
#import "ImageCache.h"

#import <CommonCrypto/CommonDigest.h>

NSString *const kKeyClientID = @"client_id";
NSString *const kKeyAccessToken = @"access_token";

NSString *const kInstagramKitAppClientIdConfigurationKey = @"InstagramKitAppClientId";
NSString *const kInstagramKitAppRedirectUrlConfigurationKey = @"InstagramKitAppRedirectURL";

NSString *const kInstagramKitBaseUrlConfigurationKey = @"InstagramKitBaseUrl";
NSString *const kInstagramKitAuthorizationUrlConfigurationKey = @"InstagramKitAuthorizationUrl";

NSString *const kInstagramKitBaseUrlDefault = @"https://api.instagram.com/v1/";
NSString *const kInstagramKitBaseUrl __deprecated = @"https://api.instagram.com/v1/";

NSString *const kInstagramKitAuthorizationUrlDefault = @"https://api.instagram.com/oauth/authorize/";
NSString *const kInstagramKitAuthorizationUrl __deprecated = @"https://api.instagram.com/oauth/authorize/";
NSString *const kInstagramKitErrorDomain = @"InstagramKitErrorDomain";

#define kData @"data"
#define kPagination @"pagination"


typedef enum {
	kPaginationMaxId,
	kPaginationMaxLikeId,
	kPaginationMaxTagId,
} MaxIdKeyType;

@interface InstagramEngine ()
{
	dispatch_queue_t mBackgroundQueue;
	dispatch_queue_t imageQueue;
}

+ (NSDictionary *)sharedEngineConfiguration;

@property (nonatomic, copy) InstagramLoginBlock instagramLoginBlock;
@property (nonatomic, strong) AFHTTPRequestOperationManager *operationManager;
@property (nonatomic, strong) NSMutableArray * operations;

    // downloads list
@property (nonatomic, strong) NSMutableArray * downloads;

@end

@implementation InstagramEngine

#pragma mark - Initializers -

+ (InstagramEngine *)sharedEngine {
	static InstagramEngine *_sharedEngine = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
	    _sharedEngine = [[InstagramEngine alloc] init];
	});
	return _sharedEngine;
}

+ (NSDictionary *)sharedEngineConfiguration {
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"InstagramKit" withExtension:@"plist"];
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:url];
	dict = dict ? dict : [[NSBundle mainBundle] infoDictionary];
	return dict;
}

- (id)init {
	if (self = [super init]) {
		NSDictionary *sharedEngineConfiguration = [InstagramEngine sharedEngineConfiguration];
		id url = nil;
		url = sharedEngineConfiguration[kInstagramKitBaseUrlConfigurationKey];

		if (url) {
			url = [NSURL URLWithString:url];
		} else {
			url = [NSURL URLWithString:kInstagramKitBaseUrlDefault];
		}

		NSAssert(url, @"Base URL not valid: %@", sharedEngineConfiguration[kInstagramKitBaseUrlConfigurationKey]);
		self.operationManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:url];

		self.appClientID =  sharedEngineConfiguration[kInstagramKitAppClientIdConfigurationKey];
		self.appRedirectURL = sharedEngineConfiguration[kInstagramKitAppRedirectUrlConfigurationKey];

		url = sharedEngineConfiguration[kInstagramKitAuthorizationUrlConfigurationKey];
		self.authorizationURL = url ? url : kInstagramKitAuthorizationUrlDefault;

		mBackgroundQueue = dispatch_queue_create("background", NULL);
		imageQueue = dispatch_queue_create("imageCache", NULL);

		self.operationManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];

		__unused BOOL validClientId = IKNotNull(self.appClientID) && ![self.appClientID isEqualToString:@""] && ![self.appClientID isEqualToString:@"<Client Id here>"];
		NSAssert(validClientId, @"Invalid Instagram Client ID.");
		NSAssert([NSURL URLWithString:self.appRedirectURL], @"App Redirect URL invalid: %@", self.appRedirectURL);
		NSAssert([NSURL URLWithString:self.authorizationURL], @"Authorization URL invalid: %@", self.authorizationURL);
	}
	return self;
}

#pragma mark - Custom method -

- (NSString *)accessToken {
    
    return [[NSUserDefaults standardUserDefaults] objectForKey:kKeyAccessToken];
}

#pragma mark - Login -

- (void)cancelLogin {
	if (self.instagramLoginBlock) {
		NSString *localizedDescription = NSLocalizedString(@"User canceled Instagram Login.", @"Error notification for Instagram Login cancelation.");
		NSError *error = [NSError errorWithDomain:kInstagramKitErrorDomain code:kInstagramKitErrorCodeUserCancelled userInfo:@{
		                      NSLocalizedDescriptionKey: localizedDescription
						  }];
		self.instagramLoginBlock(error);
	}
}

- (void)loginWithBlock:(InstagramLoginBlock)block {
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?client_id=%@&redirect_uri=%@&response_type=token&scope=relationships",
	                                   self.authorizationURL,
	                                   self.appClientID,
	                                   self.appRedirectURL]];

	self.instagramLoginBlock = block;

	[[UIApplication sharedApplication] openURL:url];
}

- (void)checkAccesTokenWithBlock:(void (^)(NSError *error))block {
    NSString *token = [[InstagramEngine sharedEngine] accessToken];

	if (!token) {
		[self renewAccessTokenWithBlock: ^(NSError *error) {
		    if (error) {
		        DLog(@"%@", [error description]);
			}

		    block(error);
		}];
	} else {
		NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:0];
		[params setObject:token forKey:kKeyAccessToken];
        
        NSString *user_id = [[NSUserDefaults standardUserDefaults] objectForKey:@"user_id"];
        NSString *path = [NSString stringWithFormat:@"users/%@", user_id ? : @""];
        
		[self.operationManager GET:path parameters:params success: ^(AFHTTPRequestOperation *operation, id responseObject) {
		    if (block) {
		        block(nil);
			}
		} failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
		    [self renewAccessTokenWithBlock: ^(NSError *error) {
		        if (error) {
		            DLog(@"%@", [error description]);
				}

		        block(error);
			}];
		}];
	}
}

- (void)renewAccessTokenWithBlock:(void (^)(NSError *error))block {
	__weak typeof(self) weakSelf = self;

	double delayInSeconds = 1.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
	    NSString *urlString = [NSString stringWithFormat:@"%@?client_id=%@&redirect_uri=%@&response_type=token&scope=relationships+comments",
	                           weakSelf.authorizationURL,
	                           weakSelf.appClientID,
	                           weakSelf.appRedirectURL];

	    WebLoginController *loginView = [WebLoginController webViewWithUrl:urlString andSuccessBlock: ^(NSString *token, UIViewController *viewController) {
	        DLog(@"your new access token is: %@", token);

            [[NSUserDefaults standardUserDefaults] setObject:token forKey:kKeyAccessToken];
            [[NSUserDefaults standardUserDefaults] synchronize];

	        [viewController dismissViewControllerAnimated:YES completion: ^{
	            block(nil);
			}];
		}];

        [loginView.view setBackgroundColor:[UIColor clearColor]];
	    [loginView setModalPresentationStyle:UIModalPresentationCurrentContext];
	    [loginView setModalTransitionStyle:UIModalTransitionStyleCoverVertical];

	    UIViewController *rootController = ((UIWindow *)[UIApplication sharedApplication].windows[0]).rootViewController;
        [rootController setModalPresentationStyle:UIModalPresentationCurrentContext];
        
//        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:loginView];
	    [rootController presentViewController:loginView animated:YES completion:nil];
	});
}

- (BOOL)  application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation {
	NSURL *appRedirectURL = [NSURL URLWithString:self.appRedirectURL];

	if (![appRedirectURL.scheme isEqual:url.scheme] || ![appRedirectURL.host isEqual:url.host]) {
		return NO;
	}

	NSString *accessToken = [self queryStringParametersFromString:url.fragment][@"access_token"];
	if (accessToken) {
        [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:kKeyAccessToken];
        [[NSUserDefaults standardUserDefaults] synchronize];
		if (self.instagramLoginBlock) self.instagramLoginBlock(nil);
	} else if (self.instagramLoginBlock)   {
		NSString *localizedDescription = NSLocalizedString(@"Authorization not granted.", @"Error notification to indicate Instagram OAuth token was not provided.");
		NSError *error = [NSError errorWithDomain:kInstagramKitErrorDomain code:kInstagramKitErrorCodeAccessNotGranted userInfo:@{
		                      NSLocalizedDescriptionKey : localizedDescription
						  }];
		self.instagramLoginBlock(error);
	}
	self.instagramLoginBlock = nil;
	return YES;
}

- (NSDictionary *)queryStringParametersFromString:(NSString *)string {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	for (NSString *param in[string componentsSeparatedByString:@"&"]) {
		NSArray *pairs = [param componentsSeparatedByString:@"="];
		if ([pairs count] != 2) continue;
		NSString *key = [pairs[0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSString *value = [pairs[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		[dict setObject:value forKey:key];
	}
	return dict;
}

#pragma mark - Base Call -

- (void)  getPath:(NSString *)path
       parameters:(NSDictionary *)parameters
    responseModel:(Class)modelClass
          success:(void (^)(id response, InstagramPaginationInfo *paginationInfo))success
          failure:(void (^)(NSError *error, NSInteger statusCode))failure {
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];

	if ([path rangeOfString:kKeyAccessToken].location == NSNotFound && !parameters[kKeyAccessToken]) {
        NSString *auth_token = [[InstagramEngine sharedEngine] accessToken];
		[params setObject:auth_token forKey:kKeyAccessToken];
	} else {
		[params setObject:self.appClientID forKey:kKeyClientID];
	}

	NSString *percentageEscapedPath = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

	[self.operationManager GET:percentageEscapedPath
	                parameters:params
	                   success: ^(AFHTTPRequestOperation *operation, id responseObject) {
	    NSDictionary *responseDictionary = (NSDictionary *)responseObject;
	    NSDictionary *pInfo = responseDictionary[kPagination];
	    InstagramPaginationInfo *paginationInfo = (pInfo) ? [[InstagramPaginationInfo alloc] initWithInfo:pInfo andObjectType:modelClass] : nil;
	    BOOL multiple = ([responseDictionary[kData] isKindOfClass:[NSArray class]]);
	    if (multiple) {
	        NSArray *responseObjects = responseDictionary[kData];
	        NSMutableArray *objects = [NSMutableArray arrayWithCapacity:responseObjects.count];
	        dispatch_async(mBackgroundQueue, ^{
	            if (modelClass) {
	                for (NSDictionary * info in responseObjects) {
	                    id model = [[modelClass alloc] initWithInfo:info];
	                    [objects addObject:model];
					}
				}
	            dispatch_async(dispatch_get_main_queue(), ^{
	                success(objects, paginationInfo);
				});
			});
		} else {
	        id model = nil;
	        if (modelClass && IKNotNull(responseDictionary[kData])) {
	            model = [[modelClass alloc] initWithInfo:responseDictionary[kData]];
			}
	        success(model, paginationInfo);
		}
	}

	                   failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
	    failure(error, [[operation response] statusCode]);
	}];
}

- (void) postPath:(NSString *)path
       parameters:(NSDictionary *)parameters
    responseModel:(Class)modelClass
          success:(InstagramObjectBlock)success
          failure:(void (^)(NSError *error, NSInteger statusCode))failure {
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    NSString *auth_token = [[InstagramEngine sharedEngine] accessToken];
	if (auth_token) {
		[params setObject:auth_token forKey:kKeyAccessToken];
	} else
		[params setObject:self.appClientID forKey:kKeyClientID];

	[self.operationManager POST:path
	                 parameters:params
	                    success: ^(AFHTTPRequestOperation *operation, id responseObject) {
	    success(responseObject);
	}

	                    failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
	    failure(error, [[operation response] statusCode]);
	}];
}

- (void)deletePath:(NSString *)path
        parameters:(NSDictionary *)parameters
     responseModel:(Class)modelClass
           success:(void (^)(void))success
           failure:(void (^)(NSError *error, NSInteger statusCode))failure {
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    NSString *auth_token = [[InstagramEngine sharedEngine] accessToken];
	if (auth_token) {
		[params setObject:auth_token forKey:kKeyAccessToken];
	} else
		[params setObject:self.appClientID forKey:kKeyClientID];
	[self.operationManager DELETE:path parameters:params success: ^(AFHTTPRequestOperation *operation, id responseObject) {
	    success();
	} failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
	    failure(error, [[operation response] statusCode]);
	}];
}

- (NSDictionary *)parametersFromCount:(NSInteger)count maxId:(NSString *)maxId andMaxIdType:(MaxIdKeyType)keyType {
	NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSString stringWithFormat:@"%ld", (long)count], kCount, nil];
	if (maxId) {
		NSString *key = nil;
		switch (keyType) {
			case kPaginationMaxId:
				key = kMaxId;
				break;

			case kPaginationMaxLikeId:
				key = kMaxLikeId;
				break;

			case kPaginationMaxTagId:
				key = kMaxTagId;
				break;
		}
		[params setObject:maxId forKey:key];
	}
	return [NSDictionary dictionaryWithDictionary:params];
}

#pragma mark - Media -


- (void)getMedia:(NSString *)mediaId
     withSuccess:(void (^)(InstagramMedia *media))success
         failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"media/%@", mediaId] parameters:nil responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        InstagramMedia *media = response;
	        success(media);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getPopularMediaWithSuccess:(InstagramMediaBlock)success
                           failure:(InstagramFailureBlock)failure {
	[self getPath:@"media/popular" parameters:nil responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    NSArray *objects = response;
	    if (success) {
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getMediaAtLocation:(CLLocationCoordinate2D)location
               withSuccess:(InstagramMediaBlock)success
                   failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"media/search?lat=%f&lng=%f", location.latitude, location.longitude] parameters:nil responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getMediaAtLocation:(CLLocationCoordinate2D)location count:(NSInteger)count maxId:(NSString *)maxId
               withSuccess:(InstagramMediaBlock)success
                   failure:(InstagramFailureBlock)failure {
	NSDictionary *params = [self parametersFromCount:count maxId:maxId andMaxIdType:kPaginationMaxId];
	[self getPath:[NSString stringWithFormat:@"media/search?lat=%f&lng=%f", location.latitude, location.longitude] parameters:params responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

#pragma mark - Users -

- (void)getUserDetails:(InstagramUser *)user
           withSuccess:(void (^)(InstagramUser *userDetail))success
               failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"users/%@", user.Id]  parameters:nil responseModel:[InstagramUser class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        InstagramUser *userDetail = response;
	        success(userDetail);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getMediaForUser:(NSString *)userId
            withSuccess:(InstagramMediaBlock)success
                failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"users/%@/media/recent", userId] parameters:nil responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getMediaForUser:(NSString *)userId count:(NSInteger)count maxId:(NSString *)maxId
            withSuccess:(InstagramMediaBlock)success
                failure:(InstagramFailureBlock)failure {
	NSDictionary *params = [self parametersFromCount:count maxId:maxId andMaxIdType:kPaginationMaxId];
	[self getPath:[NSString stringWithFormat:@"users/%@/media/recent", userId] parameters:params responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)searchUsersWithString:(NSString *)string
                  withSuccess:(void (^)(NSArray *users, InstagramPaginationInfo *paginationInfo))success
                      failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"users/search?q=%@", string] parameters:nil responseModel:[InstagramUser class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

#pragma mark - Self -


- (void)getSelfUserDetailsWithSuccess:(void (^)(InstagramUser *userDetail))success
                              failure:(InstagramFailureBlock)failure {
	[self getPath:@"users/self" parameters:nil responseModel:[InstagramUser class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    InstagramUser *userDetail = response;
	    if (success) {
	        success(userDetail);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getSelfFeedWithSuccess:(InstagramMediaBlock)success
                       failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"users/self/feed"] parameters:nil responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getSelfFeedWithCount:(NSInteger)count maxId:(NSString *)maxId
                     success:(InstagramMediaBlock)success
                     failure:(InstagramFailureBlock)failure {
	NSDictionary *params = [self parametersFromCount:count maxId:maxId andMaxIdType:kPaginationMaxId];
	[self getPath:[NSString stringWithFormat:@"users/self/feed"] parameters:params responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getMediaLikedBySelfWithSuccess:(InstagramMediaBlock)success
                               failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"users/self/media/liked"] parameters:nil responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getMediaLikedBySelfWithCount:(NSInteger)count maxId:(NSString *)maxId
                             success:(InstagramMediaBlock)success
                             failure:(InstagramFailureBlock)failure {
	NSDictionary *params = [self parametersFromCount:count maxId:maxId andMaxIdType:kPaginationMaxLikeId];
	[self getPath:[NSString stringWithFormat:@"users/self/media/liked"] parameters:params responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

#pragma mark - Relations -

- (void)getFollowingsForUser:(NSString *)userId
                 withSuccess:(InstagramUsersBlock)success
                     failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"users/%@/follows", userId] parameters:nil responseModel:[InstagramUser class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getFollowersForUser:(NSString *)userId
                withSuccess:(InstagramUsersBlock)success
                    failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"users/%@/followed-by", userId] parameters:nil responseModel:[InstagramUser class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getRelationshipForUser:(NSString *)userId
                   withSuccess:(InstagramRelationshipBlock)success
                       failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"users/%@/relationship", userId] parameters:nil responseModel:[InstagramRelationship class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
            InstagramRelationship *relationship = response;
	        success(relationship);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)postRelationshipAction:(NSString *)action
                       forUser:(NSString *)userId
                    withSuccess:(InstagramObjectBlock)success
                        failure:(InstagramFailureBlock)failure {
    [self postPath:[NSString stringWithFormat:@"users/%@/relationship", userId] parameters:@{@"action": action} responseModel:nil success:^(id response) {
	    if (success) {
	        success(response);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}


#pragma mark - Tags -

- (void)getTagDetailsWithName:(NSString *)name
                  withSuccess:(void (^)(InstagramTag *tag))success
                      failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"tags/%@", name] parameters:nil responseModel:[InstagramTag class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        InstagramTag *tag = response;
	        success(tag);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getMediaWithTagName:(NSString *)tag
                withSuccess:(InstagramMediaBlock)success
                    failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"tags/%@/media/recent", tag] parameters:nil responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)getMediaWithTagName:(NSString *)tag count:(NSInteger)count maxId:(NSString *)maxId
                withSuccess:(InstagramMediaBlock)success
                    failure:(InstagramFailureBlock)failure {
	NSDictionary *params = [self parametersFromCount:count maxId:maxId andMaxIdType:kPaginationMaxTagId];
	[self getPath:[NSString stringWithFormat:@"tags/%@/media/recent", tag] parameters:params responseModel:[InstagramMedia class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)searchTagsWithName:(NSString *)name
               withSuccess:(InstagramTagsBlock)success
                   failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"tags/search?q=%@", name] parameters:nil responseModel:[InstagramTag class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)searchTagsWithName:(NSString *)name count:(NSInteger)count maxId:(NSString *)maxId
               withSuccess:(InstagramTagsBlock)success
                   failure:(InstagramFailureBlock)failure {
	NSDictionary *params = [self parametersFromCount:count maxId:maxId andMaxIdType:kPaginationMaxId];
	[self getPath:[NSString stringWithFormat:@"tags/search?q=%@", name] parameters:params responseModel:[InstagramTag class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

#pragma mark - Comments -


- (void)getCommentsOnMedia:(InstagramMedia *)media
               withSuccess:(InstagramCommentsBlock)success
                   failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"media/%@/comments", media.Id] parameters:nil responseModel:[InstagramComment class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)createComment:(NSString *)commentText
              onMedia:(InstagramMedia *)media
          withSuccess:(InstagramObjectBlock)success
              failure:(InstagramFailureBlock)failure {
	// Please email apidevelopers@instagram.com for access.
	NSDictionary *params = [NSDictionary dictionaryWithObjects:@[commentText] forKeys:@[kText]];
	[self postPath:[NSString stringWithFormat:@"media/%@/comments", media.Id] parameters:params responseModel:nil success: ^(id response){
	    if (success) {
	        success(response);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)removeComment:(NSString *)commentId
              onMedia:(InstagramMedia *)media
          withSuccess:(void (^)(void))success
              failure:(InstagramFailureBlock)failure {
	[self deletePath:[NSString stringWithFormat:@"media/%@/comments/%@", media.Id, commentId] parameters:nil responseModel:nil success: ^{
	    if (success) {
	        success();
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

#pragma mark - Likes -


- (void)getLikesOnMedia:(InstagramMedia *)media
            withSuccess:(void (^)(NSArray *likedUsers, InstagramPaginationInfo *paginationInfo))success
                failure:(InstagramFailureBlock)failure {
	[self getPath:[NSString stringWithFormat:@"media/%@/likes", media.Id] parameters:nil responseModel:[InstagramUser class] success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)likeMedia:(InstagramMedia *)media
      withSuccess:(InstagramObjectBlock)success
          failure:(InstagramFailureBlock)failure {
	[self postPath:[NSString stringWithFormat:@"media/%@/likes", media.Id] parameters:nil responseModel:nil success: ^(id response){
	    if (success) {
	        success(response);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

- (void)unlikeMedia:(InstagramMedia *)media
        withSuccess:(void (^)(void))success
            failure:(InstagramFailureBlock)failure {
	[self deletePath:[NSString stringWithFormat:@"media/%@/likes", media.Id] parameters:nil responseModel:nil success: ^{
	    if (success) {
	        success();
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

#pragma mark - Pagination -

- (void)getPaginatedItemsForInfo:(InstagramPaginationInfo *)paginationInfo
                     withSuccess:(InstagramMediaBlock)success
                         failure:(InstagramFailureBlock)failure {
	NSString *relativePath = [[paginationInfo.nextURL absoluteString] stringByReplacingOccurrencesOfString:[self.operationManager.baseURL absoluteString] withString:@""];
	[self getPath:relativePath parameters:nil responseModel:paginationInfo.type success: ^(id response, InstagramPaginationInfo *paginationInfo) {
	    if (success) {
	        NSArray *objects = response;
	        success(objects, paginationInfo);
		}
	} failure: ^(NSError *error, NSInteger statusCode) {
	    if (failure) {
	        failure(error);
		}
	}];
}

#pragma mark - Media Content Downloading -

- (void)downloadImageWithUrl:(NSURL *)url andBlock:(void (^)(UIImage *image, NSError *error))block progressBlock:(void (^)(float progress))progressBlock {

    __strong void (^progressBlock_)(float progress) = progressBlock;
    dispatch_block_t imageBlock = ^{

        UIImage *image = [[ImageCache sharedCache] cachedImageForURL:url];
        __block NSString *filePath = [NSString stringWithFormat:@"%@/loading_%@", [[ImageCache sharedCache] cachePath], [url lastPathComponent]];
        __block NSString *completefilePath = [[ImageCache sharedCache] cachedPathForURL:url];
        
        if (image) {
            dispatch_block_t imageReadyBlock = ^{
                if (progressBlock_) {
                    progressBlock_(1.f);
                }
                if (block) {
                    block(image, nil);
                }
            };
            dispatch_async(dispatch_get_main_queue(), imageReadyBlock);
        } else {
            __block AFHTTPRequestOperation *operation = nil;
            
            // check existing operations
            NSArray *operations_ = [self.operations copy];
            for (AFHTTPRequestOperation * _operation in operations_) {
                if ([_operation.request.URL.absoluteString isEqualToString:url.absoluteString]) {
                    operation = _operation;
                    break;
                }
            }
            
            unsigned long long filesize = 0.f;
            if (!operation) {
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0f];
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                    NSFileManager * fileManager = [NSFileManager defaultManager];
                    NSDictionary *attrs = [fileManager attributesOfItemAtPath:filePath error: NULL];
                    filesize = [attrs fileSize];
                    [request setValue:[NSString stringWithFormat:@"bytes=%llu-", filesize] forHTTPHeaderField:@"Range"];
                }
                
                operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
                [operation setResponseSerializer:[AFImageResponseSerializer serializer]];
                [operation setOutputStream:[NSOutputStream outputStreamToFileAtPath:filePath append:YES]];
                [self.operations addObject:operation];
            }
            
            __weak NSMutableArray * operations = self.operations;
            [operation setCompletionBlockWithSuccess: ^(AFHTTPRequestOperation *operation, id responseObject) {
                [operations removeObject:operation];
                dispatch_block_t imageCompleteBlock = ^{
                    UIImage *image = [[ImageCache sharedCache] cachedImageForURL:url];
                    if (block) {
                        block(image, nil);
                    }
                };
                dispatch_async(dispatch_get_main_queue(), imageCompleteBlock);
                
            } failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
                [operations removeObject:operation];
                dispatch_block_t imageFailBlock = ^{
                    if (block) {
                        block(nil, error);
                    }
                };
                dispatch_async(dispatch_get_main_queue(), imageFailBlock);
            }];
            
            [operation setDownloadProgressBlock: ^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
                float progress = (float) totalBytesRead / totalBytesExpectedToRead;
                if (progressBlock_) {
                    progressBlock_(progress);
                }
                if (progress >= 1.f) {
                    // rename the loaded file
                    NSError * error;
                    [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:completefilePath error:&error];
                    if (error) {
                        DLog(@"moveItemAtPath error: %@", [error description]);
                    }
                }
            }];
            
            if (![operation isExecuting]) {
                [operation start];
            }
        }
    };
    
    dispatch_async(imageQueue, imageBlock);
}

- (NSURL *)mediaCachePath:(NSURL *)url  {
    NSString *filePath = [[ImageCache sharedCache] cachedPathForURL:url];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSURL *path = [NSURL fileURLWithPath:filePath];
        return path;
    }
    return nil;
}

- (void)downloadImageWithVideoUrl:(NSURL *)url andBlock:(void (^)(NSURL *filePathUrl, NSError *error))block progressBlock:(void (^)(float progress))progressBlock {
    
    __block NSString *filePath = [NSString stringWithFormat:@"%@/loading_%@", [[ImageCache sharedCache] cachePath], [url lastPathComponent]];
    __block NSString *completefilePath = [[ImageCache sharedCache] cachedPathForURL:url];
    if ([[NSFileManager defaultManager] fileExistsAtPath:completefilePath]) {
        NSURL *path = [NSURL fileURLWithPath:completefilePath];
        block(path, nil);
    } else {
        __block AFHTTPRequestOperation *operation = nil;
        
        // check existing operations
        NSArray *operations_ = [self.operations copy];
        for (AFHTTPRequestOperation * _operation in operations_) {
            if ([_operation.request.URL.absoluteString isEqualToString:url.absoluteString]) {
                operation = _operation;
                break;
            }
        }
        
        unsigned long long filesize = 0.f;
        if (!operation) {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                     cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0f];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                NSFileManager * fileManager = [NSFileManager defaultManager];
                NSDictionary *attrs = [fileManager attributesOfItemAtPath:filePath error: NULL];
                filesize = [attrs fileSize];
                [request setValue:[NSString stringWithFormat:@"bytes=%llu-", filesize] forHTTPHeaderField:@"Range"];
            }
            
            operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
            [operation setResponseSerializer:[AFImageResponseSerializer serializer]];
            [operation setOutputStream:[NSOutputStream outputStreamToFileAtPath:filePath append:YES]];
            [self.operations addObject:operation];
        }

        __weak NSMutableArray * operations = self.operations;
		[operation setCompletionBlockWithSuccess: ^(AFHTTPRequestOperation *operation, id responseObject) {
            [operations removeObject:operation];
            NSURL *path = [NSURL fileURLWithPath:completefilePath];
            block(path, nil);

		} failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
            [operations removeObject:operation];
		    if (block) {
		        block(nil, error);
			}
		}];
        
		if (progressBlock) {
			[operation setDownloadProgressBlock: ^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
			    float progress = (float) totalBytesRead / totalBytesExpectedToRead;
                if (progressBlock) {
                    progressBlock(progress);
                }
                if (progress >= 1.f) {
                        // rename the loaded file
                    NSError * error;
                    [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:completefilePath error:&error];
                    if (error) {
                        DLog(@"moveItemAtPath error: %@", [error description]);
                    }
                }
			}];
		}
        
        if (![operation isExecuting]) {
            [operation start];
        }
    }
}

- (NSMutableArray *)operations {
    if (!_operations) {
        _operations = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return _operations;
}

// ...
- (void)stopDownloadWithUrl:(NSString *)url {
    AFHTTPRequestOperation * _operation = [self operationWithUrl:url];
    if (_operation) {
        [self.operations removeObject:_operation];
        [_operation cancel];
    }
}

// ...
- (AFHTTPRequestOperation *)operationWithUrl:(NSString *)url {
    NSArray *operations_ = [self.operations copy];
    for (AFHTTPRequestOperation * _operation in operations_) {
        if ([_operation.request.URL.absoluteString isEqualToString:url]) {
            return _operation;
        }
    }
    return nil;
}

- (NSString *)cacheUrl:(NSURL *)url {
	// save to file
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
	                                                     NSUserDomainMask, YES);
	NSString *documentsDirectory = [NSString stringWithFormat:@"%@%@", [paths objectAtIndex:0], @"/imageCache"];

	// create subfolder
	NSError *error;
	NSString *dataPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/imageCache"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath])
		[[NSFileManager defaultManager] createDirectoryAtPath:dataPath
		                          withIntermediateDirectories:NO
		                                           attributes:nil error:&error];

	NSString *path = [documentsDirectory stringByAppendingPathComponent:
	                  [NSString stringWithString:[self MD5:url.absoluteString]]];

	return path;
}

- (NSString *)MD5:(NSString *)str {
	if (self == nil || [str length] == 0)
		return nil;

	const char *value = [str UTF8String];

	unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
	CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);

	NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
	for (NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++) {
		[outputString appendFormat:@"%02x", outputBuffer[count]];
	}

	return outputString;
}

@end

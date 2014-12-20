//
//  ObjectCache.h
//  Minimalist
//
//  Created by Timur Begaliev on 1/13/14.
//
//

#import <Foundation/Foundation.h>

@interface ImageCache : NSObject {
    
    NSMutableDictionary *_cacheDic;
}

+ (ImageCache *)sharedCache;

- (void)cacheObject:(id)obj forKey:(id)key;
- (id)cachedObjectForKey:(id)key;

- (void)respondToMemoryWarning;

- (UIImage *)renderImage:(UIImage *)image;
- (UIImage *)cachedImageForURLStr:(NSString *)urlStr __attribute((ns_returns_retained));
- (UIImage *)cachedImageForURL:(NSURL *)url;
- (void)cacheImage:(UIImage *)image withURLStr:(NSString *)urlStr;
- (void)removeImageForURLStr:(NSString *)urlStr;
- (void)clearCacheDirectory;
- (void)clearCache;
- (NSString *)cachePath;
- (NSString *)cachedPathForURL:(NSURL *)url;

@end

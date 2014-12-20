//
//  ObjectCache.m
//  Minimalist
//
//  Created by Timur Begaliev on 1/13/14.
//
//

#import "ImageCache.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import <CommonCrypto/CommonDigest.h>

#define LimitForImages 300

@interface ImageCache ()

bool CGImageWriteToFile(CGImageRef image, NSString *path);

@end

@implementation ImageCache

static ImageCache *_instance = nil;

+ (ImageCache *)sharedCache {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [ImageCache new];
    });
    
    return _instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        
        _cacheDic = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    return self;
}

- (void)cacheObject:(id)obj forKey:(id)key {
    if (obj) {
        [_cacheDic setObject:obj forKey:key];
    }

}

- (id)cachedObjectForKey:(id)key {
    
    return [_cacheDic objectForKey:key];
}

// Clear the cache at a memory warning
- (void) respondToMemoryWarning {

    [_cacheDic removeAllObjects];
    
}

- (UIImage *)renderImage:(UIImage *)image {
    
    // rendering code is from http://www.artlebedev.ru/tools/technogrette/etc/big-image-table/
    CGImageRef originalImage = [image CGImage];
//    assert(originalImage != NULL);
    if (originalImage == NULL) {
        return nil;
    }
    
    CFDataRef imageData = CGDataProviderCopyData(CGImageGetDataProvider(originalImage));
    CGDataProviderRef imageDataProvider = CGDataProviderCreateWithCFData(imageData);
    if (imageData != NULL) {
        CFRelease(imageData);
    }
    CGImageRef rawImage = CGImageCreate(CGImageGetWidth(originalImage),
                                        CGImageGetHeight(originalImage),
                                        CGImageGetBitsPerComponent(originalImage),
                                        CGImageGetBitsPerPixel(originalImage),
                                        CGImageGetBytesPerRow(originalImage),
                                        CGImageGetColorSpace(originalImage),
                                        CGImageGetBitmapInfo(originalImage),
                                        imageDataProvider,
                                        CGImageGetDecode(originalImage),
                                        CGImageGetShouldInterpolate(originalImage),
                                        CGImageGetRenderingIntent(originalImage));
    if (imageDataProvider != NULL) {
        CGDataProviderRelease(imageDataProvider);
    }
    
    // Do something with the image.
    UIImage *retVal = [UIImage imageWithCGImage:rawImage];
    CGImageRelease(rawImage);
    return retVal;
}

bool CGImageWriteToFile(CGImageRef image, NSString *path) {
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypeJPEG, 1, NULL);
    CGImageDestinationAddImage(destination, image, nil);
    
    if (!CGImageDestinationFinalize(destination)) {
        CFRelease(destination);
        return false;
    }
    
    CFRelease(destination);
    return true;
}

- (void)cacheImage:(UIImage *)image withURLStr:(NSString *)urlStr {
    NSURL *tempFolderURL = [NSURL fileURLWithPath:[self cachePath]];
    if (tempFolderURL) {
        NSString *fileName = [urlStr lastPathComponent];
        tempFolderURL = [tempFolderURL URLByAppendingPathComponent:fileName];
        CGImageWriteToFile(image.CGImage, [tempFolderURL path]);
    }
}

- (UIImage *)cachedImageForURLStr:(NSString *)urlStr {
    
    id cachedObj = [[ImageCache sharedCache] cachedObjectForKey:urlStr];
    if (cachedObj) {
        return cachedObj;
    } else {
        UIImage *retVal = nil;
        NSString *completefilePath = [NSString stringWithFormat:@"%@/%@", [self cachePath], [urlStr lastPathComponent]];
        NSData *data = [[NSData alloc] initWithContentsOfFile:completefilePath];
            if (data) {
                if ([self dataIsValidJPEG:data]) {
                    retVal = [[UIImage alloc] initWithData:data];
                    retVal = [self renderImage:retVal];
                }
        }
        if (retVal)
            [[ImageCache sharedCache] cacheObject:retVal forKey:urlStr];
        
        return retVal;
    }
}

- (UIImage *)cachedImageForURL:(NSURL *)url {
    
    UIImage *image = [self cachedImageForURLStr:url.absoluteString];
    
    return image;
}

- (void)removeImageForURLStr:(NSString *)urlStr {
    NSURL *tempFolderURL = [NSURL fileURLWithPath:[self cachePath]];
    if (tempFolderURL) {
        NSString *fileName = [urlStr lastPathComponent];
        tempFolderURL = [tempFolderURL URLByAppendingPathComponent:fileName];
        NSFileManager *fileman = [NSFileManager defaultManager];
        if ([fileman fileExistsAtPath:[tempFolderURL path]]) {
            [fileman removeItemAtURL:tempFolderURL error:nil];
            DLog(@"temp image is deleted");
        }
    }
}

- (NSString *)cachedPathForURL:(NSURL *)url {    
    NSString *fileName = [url lastPathComponent];
    NSString *cachedPath = [NSString stringWithFormat:@"%@/%@", [self cachePath], fileName];
    return cachedPath;
}

- (NSString *)cachePath {
    
	NSString *dataPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ImageCache"];
	// create subfolder if doesn't exist
	NSError *error;
	if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath])
		[[NSFileManager defaultManager] createDirectoryAtPath:dataPath
		                          withIntermediateDirectories:NO
		                                           attributes:nil error:&error];
	return dataPath;
}

- (void)clearCacheDirectory {
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self cachePath] error:NULL];
    for (NSString *file in items) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", [self cachePath], file] error:NULL];
    }
}

- (void)clearCache {
    
    // removing images after they exceed cache limit
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self cachePath] error:NULL];
    if ([items count] > LimitForImages) {
        [self clearCacheDirectory];
    } else {
        // removing all mp4 files
        NSArray *mp4Files = [items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.mp4'"]];
        for (NSString *file in mp4Files) {
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", [self cachePath], file] error:NULL];
        }
    }
    [_cacheDic removeAllObjects];
}


#pragma mark - utility methods
//
//- (NSString *)MD5FromString:(NSString *)originalString {
//    
//    if(self == nil || [originalString length] == 0)
//        return nil;
//    
//    const char *value = [originalString UTF8String];
//    
//    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
//    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
//    
//    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
//    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
//        [outputString appendFormat:@"%02x",outputBuffer[count]];
//    }
//    
//    return outputString;
//}

-(BOOL)dataIsValidJPEG:(NSData *)data
{
    if (!data || data.length < 2) return NO;
    
    NSInteger totalBytes = data.length;
    const char *bytes = (const char*)[data bytes];
    
    return (bytes[0] == (char)0xff &&
            bytes[1] == (char)0xd8 &&
            bytes[totalBytes-2] == (char)0xff &&
            bytes[totalBytes-1] == (char)0xd9);
}

@end

